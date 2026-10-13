<?php

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Content-Type');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

require_once __DIR__ . '/db.php';

function respond(int $statusCode, array $data): never
{
    http_response_code($statusCode);
    echo json_encode($data);
    exit;
}

function requestBody(): array
{
    $rawBody = file_get_contents('php://input');
    $body = json_decode($rawBody, true);

    if (!is_array($body)) {
        respond(400, [
            'ok' => false,
            'error' => 'Request body must be valid JSON'
        ]);
    }

    return $body;
}

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $body = requestBody();

    $imageName = trim((string)($body['imageName'] ?? ''));
    $prediction = trim((string)($body['prediction'] ?? ''));
    $confidence = $body['confidence'] ?? null;
    $dateTime = trim((string)($body['dateTime'] ?? ''));

    if (
        $imageName === '' ||
        $prediction === '' ||
        !is_numeric($confidence) ||
        $dateTime === ''
    ) {
        respond(422, [
            'ok' => false,
            'error' => 'imageName, prediction, confidence, and dateTime are required'
        ]);
    }

    $confidence = (float)$confidence;

    if ($confidence < 0 || $confidence > 1) {
        respond(422, [
            'ok' => false,
            'error' => 'confidence must be between 0 and 1'
        ]);
    }

    try {
        $date = new DateTime($dateTime);
        $mysqlDateTime = $date->format('Y-m-d H:i:s');
    } catch (Exception) {
        respond(422, [
            'ok' => false,
            'error' => 'dateTime must be a valid date/time'
        ]);
    }

    $statement = $conn->prepare(
        'INSERT INTO ImagePredictions
            (ImageName, Prediction, Confidence, `DateTime`)
         VALUES (?, ?, ?, ?)'
    );

    if ($statement === false) {
        respond(500, [
            'ok' => false,
            'error' => 'Failed to prepare insert statement'
        ]);
    }

    $statement->bind_param(
        'ssds',
        $imageName,
        $prediction,
        $confidence,
        $mysqlDateTime
    );

    if (!$statement->execute()) {
        $databaseError = $statement->error;
        $statement->close();

        error_log('Failed to store prediction: ' . $databaseError);

        respond(500, [
            'ok' => false,
            'error' => 'Failed to store prediction',
            'details' => $databaseError,
        ]);
    }

    $imageId = $statement->insert_id;
    $statement->close();

    respond(201, [
        'ok' => true,
        'message' => 'Prediction stored successfully',
        'imageId' => $imageId
    ]);
}

if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    $result = $conn->query(
        'SELECT ImageID, ImageName, Prediction, Confidence, `DateTime`
         FROM ImagePredictions
         ORDER BY `DateTime` DESC, ImageID DESC'
    );

    if ($result === false) {
        respond(500, [
            'ok' => false,
            'error' => 'Failed to retrieve predictions'
        ]);
    }

    $records = [];

    while ($row = $result->fetch_assoc()) {
        $records[] = [
            'imageId' => (int)$row['ImageID'],
            'imageName' => $row['ImageName'],
            'prediction' => $row['Prediction'],
            'confidence' => (float)$row['Confidence'],
            'dateTime' => $row['DateTime'],
        ];
    }

    respond(200, [
        'ok' => true,
        'records' => $records
    ]);
}

respond(405, [
    'ok' => false,
    'error' => 'Method not allowed'
]);
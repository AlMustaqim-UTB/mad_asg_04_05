<?php
header('Content-Type: application/json');

mysqli_report(MYSQLI_REPORT_OFF);

$conn = new mysqli('db', 'mus', '1221', 'app_db');

if ($conn->connect_error) {
    http_response_code(500);
    header('Content-Type: application/json');

    echo json_encode([
        'ok' => false,
        'error' => 'Database connection failed'
    ]);

    exit;
}

$conn->set_charset('utf8mb4');
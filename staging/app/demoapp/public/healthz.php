<?php
declare(strict_types=1);

header('Content-Type: application/json');

$expected = getenv('MYAPP_TOKEN') ?: 'dev-token';
$actual = $_GET['token'] ?? '';

if (!hash_equals($expected, (string)$actual)) {
    http_response_code(403);
    echo json_encode(['ok' => false, 'error' => 'invalid token']);
    exit;
}

echo json_encode([
    'ok' => true,
    'time' => gmdate('c'),
    'app_data' => getenv('MYAPP_DATA') ?: null,
    'cache' => getenv('MYAPP_CACHE') ?: null,
]);

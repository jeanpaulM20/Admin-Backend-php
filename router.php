<?php
// Inject CORS headers for all API requests
if (strpos($_SERVER['REQUEST_URI'], '/api/') !== false) {
    $origin = isset($_SERVER['HTTP_ORIGIN']) ? $_SERVER['HTTP_ORIGIN'] : '*';
    header('Access-Control-Allow-Origin: ' . $origin);
    header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
    header('Access-Control-Allow-Headers: Content-Type, X-Auth-Token, X-Requested-With, Authorization, Accept');
    header('Access-Control-Allow-Credentials: true');
    header('Access-Control-Max-Age: 86400');

    // Handle OPTIONS preflight — respond immediately
    if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
        http_response_code(200);
        header('Content-Length: 0');
        exit(0);
    }
}

// Falls es sich um eine statische Datei handelt (Bild, CSS, JS...), direkt ausliefern
if (preg_match('/\.(?:png|jpg|jpeg|gif|css|js|ico|svg)$/', $_SERVER["REQUEST_URI"])) {
    return false;
}

// Ansonsten die index.php aufrufen
$_SERVER['SCRIPT_NAME'] = '/index.php';
require_once __DIR__ . '/index.php';

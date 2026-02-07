<?php
// Falls es sich um eine statische Datei handelt (Bild, CSS, JS...), direkt ausliefern
if (preg_match('/\.(?:png|jpg|jpeg|gif|css|js|ico|svg)$/', $_SERVER["REQUEST_URI"])) {
    return false;
}

// Ansonsten die index.php aufrufen
$_SERVER['SCRIPT_NAME'] = '/index.php';
require_once __DIR__ . '/index.php';

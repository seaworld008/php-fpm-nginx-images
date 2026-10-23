<?php
$out = array('sapi' => PHP_SAPI, 'version' => PHP_VERSION, 'uid' => function_exists('posix_geteuid') ? posix_geteuid() : null,
    'tmp' => sys_get_temp_dir(), 'ini_files' => php_ini_loaded_file() . ' | ' . php_ini_scanned_files());
foreach (ini_get_all(null, false) as $k => $v) {
    $out['ini'][$k] = $v;
}
foreach (get_loaded_extensions() as $e) {
    $out['ext'][strtolower($e)] = phpversion($e);
}
foreach (get_loaded_extensions(true) as $e) {
    $out['zend'][strtolower($e)] = phpversion($e);
}
echo json_encode($out);

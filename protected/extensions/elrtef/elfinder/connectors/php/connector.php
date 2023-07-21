<?php
if(@$_GET['passkey']!=='t1fq4mstun8oq6hh606hn28fld') die("You have no access to do it!");

error_reporting(0);

include_once dirname(__FILE__).DIRECTORY_SEPARATOR.'elFinder.class.php';

$opts = array(
	'root'            => '../../../../../media',
	'URL'             => preg_replace('#/assets/(.*)#i', '/media/', $_SERVER['REQUEST_URI']),
	'rootAlias'       => 'Media',
 	'imgLib'       => 'gd',
	'tmbCrop'		=> false,
);

$fm = new elFinder($opts); 
$fm->run();

?>

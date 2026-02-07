<?php

$notWritable = array();

if (!is_writable(dirname(__FILE__) .  '/../assets')) {
	$notWritable[] = 'assets';
}

if (!is_writable(dirname(__FILE__) . '/../media')) {
	$notWritable[] = 'media';
}

if (!is_writable(dirname(__FILE__) . '/runtime')) {
	$notWritable[] = 'protected/runtime';
}

if (count($notWritable) && PHP_OS == 'Linux') {
	echo 'The following directories should be writable: <br/>';
	echo implode('<br/>', $notWritable);
	die();
}

if (file_exists(dirname(__FILE__) . '/runtime/dbupdate.run')) {
	$commandPath = Yii::app()->getBasePath() . DIRECTORY_SEPARATOR . 'commands';
	$runner = new CConsoleCommandRunner();
	$runner->addCommands($commandPath);
	$commandPath = Yii::getFrameworkPath() . DIRECTORY_SEPARATOR . 'cli' . DIRECTORY_SEPARATOR . 'commands';
	$runner->addCommands($commandPath);
	$args = array('yiic', 'migrate', '--interactive=0');
	ob_start();
	$runner->run($args);
	echo htmlentities(nl2br(ob_get_clean()), ENT_QUOTES | ENT_SUBSTITUTE, Yii::app()->charset);
	unlink(dirname(__FILE__) . '/runtime/dbupdate.run');
	die('<br/>Please refresh the page!!!');
}

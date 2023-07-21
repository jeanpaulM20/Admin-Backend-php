<?php

class ApiResource {
	public $basePath;
	public $resourcePath;
	public $swaggerVersion = '1.0';
	public $apiVersion = '1.0';
	public $apis = array();
	
	public function __construct() {
		$this->basePath = Yii::app()->getRequest()->getHostInfo('http') . Yii::app()->urlManager->createUrl("api");
	}
	
	public function addApi($api) {
		$this->apis[] = $api;
	}
}
?>

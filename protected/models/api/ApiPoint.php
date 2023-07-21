<?php

class ApiPoint {
	public $path;
	public $description = "";
	public $operations = array();
	
	public function addOperation($op) {
		$this->operations[] = $op;
	}
}
?>

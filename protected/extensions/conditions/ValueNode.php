<?php

class ValueNode extends ASTNode
{
	protected $_value;
	
	public function __construct($value) {
		$this->_value = $value;
	}

	public function getValue() {
		return $this->_value;
	}

	public function setValue($value) {
		$this->_value = $value;
	}
	
	public function toDbCriteria($mainModel, $criteria = null) {
		if (strtoupper($this->_value) == 'EMPTY') {
			return array('""', null);
		}
		if (Tokenizer::checkIsString($this->_value)) {
			$value = str_replace('\\"', '"', trim($this->_value, '"'));
			return $value;
		} else {
			return $this->_value;
		}
	}

	public function __toString() {
		return $this->_value;
	}
		
}
?>
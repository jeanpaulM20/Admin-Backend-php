<?php

class ListNode extends ASTNode
{
	protected $_items = array();
	
	public function addItem($item) 
	{
		$this->_items[] = $item;
	}
	
	public function __toString() {
		$data = array();
		foreach ($this->_items as $one) {
			$data[] = $one->__toString();
		}
		return '(' . implode(', ', $data) . ')';
	}

	public function toDbCriteria($mainModel, $criteria = null) {
		$values = array();
		foreach ($this->_items as $one) {
			$values[] = $one->toDbCriteria($mainModel, $criteria);
		}
		return $values;
	}
}
?>

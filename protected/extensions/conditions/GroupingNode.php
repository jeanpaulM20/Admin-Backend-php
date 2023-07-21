<?php

class GroupingNode extends ASTNode
{
	protected $_group;
	
	public function __construct($group) {
		$this->_group = $group;
	}
	
	public function setGroup($group) {
		$this->_group = $group;
	}
	
	public function toDbCriteria($mainModel, $criteria = null) {
		return $this->_group->toDbCriteria($mainModel, $criteria);
	}
	
	public function __toString() {
		return '(' . $this->_group . ')';
	}
}
?>

<?php

class AndNode extends ASTNode
{
	protected $_leafs = array();
	
	public function addLeaf($leaf) {
		$this->_leafs[] = $leaf;
	}
	
	public function toDbCriteria($mainModel, $criteria = null) {
		$andCriteria = new CDbCriteria;
		foreach ($this->_leafs as $leaf) {
			$andCriteria->mergeWith($leaf->toDbCriteria($mainModel, $criteria));
		}
		return $andCriteria;
	}
	
	public function __toString() {
		$data = array();
		foreach ($this->_leafs as $leaf) {
			$data[] = $leaf->__toString();
		} 
		return implode(' AND ', $data);
	}
}
?>

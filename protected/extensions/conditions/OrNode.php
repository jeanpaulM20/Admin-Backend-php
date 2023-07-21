<?php

class OrNode extends ASTNode
{
	protected $_leafs = array();
	
	public function addLeaf($leaf) {
		$this->_leafs[] = $leaf;
	}
	
	public function toDbCriteria($mainModel, $criteria = null) {
		$orCriteria = new CDbCriteria;
		foreach ($this->_leafs as $leaf) {
			$orCriteria->mergeWith($leaf->toDbCriteria($mainModel, $criteria), false);
		}
		return $orCriteria;
	}
	
	public function __toString() {
		$data = array();
		foreach ($this->_leafs as $leaf) {
			$data[] = $leaf->__toString();
		} 
		return implode(' OR ', $data);
	}
}
?>

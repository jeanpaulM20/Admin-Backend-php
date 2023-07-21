<?php

abstract class ASTNode
{
	abstract public function toDbCriteria($mainModel, $criteria = null);
	abstract public function __toString();
}
?>

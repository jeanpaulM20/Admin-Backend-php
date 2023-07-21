<?php

class FieldNode extends ASTNode
{
	protected $_name;
	
	public function __construct($name) {
		$this->_name = $name;
	}
	
	public function getName() {
		return $this->_name;
	}

	public function setName($name) {
		$this->_name = $name;
	}

	public function toDbCriteria($mainModel, $criteria = null) {
		$model = Helper::getModel($mainModel);
		$modelName = $mainModel;
		$list = explode('.', $this->_name);
		$field = array_pop($list);
		foreach ($list as $one) {
			$relations = $model->relations();
			if (isset($relations[$one])) {
				//$model = Helper::getModel(strtolower($relations[$one][1]));
				$model = new $relations[$one][1]();
				$modelName = $one;
			} else {
				throw new ParserException('Model ' . $modelName . ' does not have relation ' . $this->_name);
			}
		}
		if (!$model->hasAttribute($field)) {
			throw new ParserException('Model ' . $modelName . ' does not have attribute ' . $field);
		}
		if (count($list) > 0) {
			if ($criteria->with) {
				$criteria->with = array_merge($criteria->with, array(implode('.', $list)));
			} else {
				$criteria->with = array(implode('.', $list));
			}
			$criteria->together = true;
		}
		if ($modelName == $mainModel) {
			return 't.' . $field;
		} else {
			return $modelName . '.' . $field;
		}
		
	}

	public function __toString() {
		return $this->_name;
	}
	
}
?>

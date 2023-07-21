<?php

abstract class ActiveRecord extends CActiveRecord
{
	
	public function getLocalizableAttributes()
	{
		return array();
	}
	
	public function getAttributesWithLocalisation()
	{
		$arrtibutes = $this->attributes;
		$localizable = $this->getLocalizableAttributes();
		$result = array();
		foreach ($arrtibutes as $key => $value) {
			if (in_array($key, $localizable)) {
				$result = $this->addLocaleToArray($result, $key, $value);
			} 
			$result[$key] = $value;
		}
		
		return $result;
	}
	
	public function addLocaleToArray($data, $key, $value)
	{
		$langs = Language::model()->findAll();
		foreach ($langs as $lang) {
			$translation = Translation::model()->find('label = :label AND language_rel = :lang', array(
				'label' => $value,
				'lang' => $lang->id
			));
			$k = $key . '_' . $lang->language;
			$v = ($translation ? $translation->value : $value);
			$data[$k] = $v;
		}
		return $data;
	}
	
	public function populateRecords($data,$callAfterFind=true,$index=null)
	{
		$records=array();
		foreach($data as $attributes)
		{
			if(($record=$this->populateRecord($attributes,$callAfterFind))!==null)
			{
				if($index===null)
					$records[]=$record;
				else
					$records[$record->$index]=$record;
			}
		}
		$this->afterFindAll();
		return $records;
	}
	
	public function afterFindAll()
	{
		if($this->hasEventHandler('onAfterFindAll')) {
			$event=new CModelEvent($this);
			$this->onAfterFindAll($event);
		}
	}
	
	public function onAfterFindAll($event)
	{
		$this->raiseEvent('onAfterFindAll',$event);
	}

	public function getCodeByLabel($label)
	{
		$key = array_search($label, $this->attributeLabels());
		if ($key) {
			return $key;
		} else {
			return $label;
		}
	}
	
	public function convertValue($code, $value) {
		if (isset($this->getMetaData()->columns[$code])) {
			$column = $this->getMetaData()->columns[$code];
			switch($column->type) {
				case 'integer':
					if ($value == 'x') {
						return 1;
					}
					if ($this->isRelationField($code)) {
						return $this->getRelationFieldValue($code, $value);
					}
					return (int)$value;
				default:
					if (method_exists($this, 'get' . ucfirst($code) . 'Values')) {
						$method = 'get' . ucfirst($code) . 'Values';
						$values = $this->$method();
						return array_search($value, $values);
					}
					return $value;
			}
		} else {
			return $value;
		}
	}
	
	public function isRelationField($name)
	{
		return $this->getRelationForField($name) !== false;
	}
	
	public function getRelationForField($name) {
		foreach ($this->getMetaData()->relations as $relation) {
			if ($relation instanceof CBelongsToRelation && $relation->foreignKey == $name) {
				return $relation;
			}
		}
		return false;
	}
	
	public function getRelationFieldValue($code, $value)
	{
		$relation = $this->getRelationForField($code);
		$relatedModel = new $relation->className;
		$result = $relatedModel->findByModelDisplay($value);
		if ($result) {
			return $result->getPrimaryKey();
		}
		return null;
	}
	
	public function importCsv($data)
	{
		$transaction = Yii::app()->db->beginTransaction();
		$i = 0;
		$pk = $this->getMetaData()->tableSchema->primaryKey;
		
		foreach ($data as $one) {
			$i++;
			$model = $this->getModel();
			if (isset($one[$pk])) {
				$model = $model->findByPk($one[$pk]);
			}
			foreach ($one as $label => $value) {
				$code = $this->getCodeByLabel($label);
				$model->setAttribute(
						$code, 
						$this->convertValue($code, $value));
			}
			if (!$model->save()) {
				$transaction->rollback();
				return array('line' => $i, 'model' => $model);
			}
		}
		$transaction->commit();
		return false;
	}
}
?>
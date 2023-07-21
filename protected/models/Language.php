<?php

/**
 * @property integer $id	
 * @property string $language	
 */
class Language extends ActiveRecord
{

	
	
	
	protected $language_values = array(
	'de' => 'Deutsch',
	'en' => 'English',
);

public function getLanguageValues() {
	return $this->language_values;
}

public function getLanguage() {
	if ($this->language) {
		return $this->language_values[$this->language];
	}
}



	/**
	 * Returns the static model of the specified AR class.
	 * @param string $className active record class name.
	 * @return $name the static model class
	 */
	public static function model($className=__CLASS__)
	{
		return parent::model($className);
	}

	/**
	 * @return string the associated database table name
	 */
	public function tableName()
	{
		return '{{language}}';
	}

	/**
	 * @return array validation rules for model attributes.
	 */
	public function rules()
	{
		// NOTE: you should only define rules for those attributes that
		// will receive user inputs.
		return array(
			array('language','in','range'=> array_keys($this->getLanguageValues()),'allowEmpty'=>false),
			array('id', 'numerical', 'integerOnly'=>true),
			array('id, language', 'safe'),
			array('id, language', 'safe', 'on' => 'search'),
		);
	}

	/**
	 * @return array relational rules.
	 */
	public function relations()
	{
		return array(
			
			
		);
	}
	
	public function behaviors()
	{
		return array(
			'activerecord-relation'=>array(
				'class'=>'ext.yiiext.behaviors.activerecord-relation.EActiveRecordRelationBehavior',
		));
	}

	/**
	 * @return array customized attribute labels (name=>label)
	 */
	public function attributeLabels()
	{
		return array(
			'id' => 'id',
			'language' => 'Language',
		);
	}

	/**
	 * Retrieves a list of models based on the current search/filter conditions.
	 * @return CActiveDataProvider the data provider that can return the models based on the search/filter conditions.
	 */
	public function search()
	{
		$criteria=new CDbCriteria;
		$criteria->with = array();
		$criteria->compare('t.id',$this->id);
		$criteria->compare('t.language',$this->language);

		return new CActiveDataProvider($this, array(
			'pagination'=>array(
				'pageSize'=> Yii::app()->user->getState('pageSize',Yii::app()->params['defaultPageSize']),
			),
			'criteria'=>$criteria,
			'sort'=>array(
				'attributes'=>array(
		
		
					'*',
				),
			),
		));
	}
	
	
	public static function getDropdownList($withEmpty = false) {
		$models = self::model()->findAll();
		$list = array();
		if ($withEmpty) {
			$list[''] = ' ';
		}
		foreach ($models as $model) {
			$list[$model->getPrimaryKey()] = $model->getModelDisplay();
		}
		return $list;
	}

	public function getModelDescription()
	{
		$obj = new stdClass();
		$obj->fields = $this->attributeLabels();
		$obj->titleFields = array('language');
		$obj->title = 'Language';
		return $obj;
	}
	
	public function getModelDisplay()
	{
		return "$this->language ";
	}
}
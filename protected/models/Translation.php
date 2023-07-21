<?php

/**
 * @property integer $id	
 * @property string $label	
 * @property string $value	
 * @property integer $language_rel	
 */
class Translation extends ActiveRecord
{

	
	
	
	
	
	
	public $language_search;
	

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
		return '{{translation}}';
	}

	/**
	 * @return array validation rules for model attributes.
	 */
	public function rules()
	{
		// NOTE: you should only define rules for those attributes that
		// will receive user inputs.
		return array(
			array('id, language_rel', 'numerical', 'integerOnly'=>true),
			array('label, value', 'length', 'max'=>255),
			array('id, label, value, language_rel, language_search', 'safe'),
			array('id, label, value, language_rel, language_search', 'safe', 'on' => 'search'),
		);
	}

	/**
	 * @return array relational rules.
	 */
	public function relations()
	{
		return array(
			
			
			
			'language' => array(self::BELONGS_TO, 'Language', 'language_rel'),
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
			'label' => 'Label',
			'value' => 'Value',
			'language_rel' => 'Language',
			'language_search' => 'Language',
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
		$criteria->compare('t.label',$this->label,true);
		$criteria->compare('t.value',$this->value,true);
		$criteria->with[] = 'language';
$language_search = new CDbCriteria;
$language_search->compare('language.language',$this->language_search,true, 'OR');
$criteria->mergeWith($language_search);

		return new CActiveDataProvider($this, array(
			'pagination'=>array(
				'pageSize'=> Yii::app()->user->getState('pageSize',Yii::app()->params['defaultPageSize']),
			),
			'criteria'=>$criteria,
			'sort'=>array(
				'attributes'=>array(
		
		
		
		'language_search'=>array('asc'=>'language.language','desc'=>'language.language DESC',),
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
		$obj->titleFields = array('id');
		$obj->title = 'Translation';
		return $obj;
	}
	
	public function getModelDisplay()
	{
		return "$this->id ";
	}
}
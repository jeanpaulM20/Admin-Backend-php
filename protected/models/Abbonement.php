<?php

/**
 * @property integer $id	
 * @property integer $training_type_id
 * @property string $title
 * @property integer $duration
 * @property integer $lessons
 * @property integer $participants
 */
class Abbonement extends ActiveRecord
{

	/**
	 * Returns the static model of the specified AR class.
	 * @param string $className active record class name.
	 * @return $name the static model class
	 */
	public static function model($className = __CLASS__)
	{
		return parent::model($className);
	}

	/**
	 * @return string the associated database table name
	 */
	public function tableName()
	{
		return '{{abbonement}}';
	}

	/**
	 * @return array validation rules for model attributes.
	 */
	public function rules()
	{
		// NOTE: you should only define rules for those attributes that
		// will receive user inputs.
		return array(
			array('id, training_type_id', 'numerical', 'integerOnly' => true),
			array('id, training_type_id, title, duration, lessons, participants, price', 'safe'),
			array('id, training_type_id, title, duration, lessons, participants, price', 'safe', 'on' => 'search'),
		);
	}

	/**
	 * @return array relational rules.
	 */
	public function relations()
	{
		return array(
			'training_type' => array(self::BELONGS_TO, 'TrainingType', 'training_type_id'),
		);
	}

	public function behaviors()
	{
		return array(
			'activerecord-relation' => array(
				'class' => 'ext.yiiext.behaviors.activerecord-relation.EActiveRecordRelationBehavior',
				));
	}

	/**
	 * @return array customized attribute labels (name=>label)
	 */
	public function attributeLabels()
	{
		return array(
			'training_type_id' => 'Training type',
			'title' => 'Title',
			'duration' => 'Expiry date in month',
			'lessons' => 'Number of lessons'
		);
	}

	/**
	 * Retrieves a list of models based on the current search/filter conditions.
	 * @return CActiveDataProvider the data provider that can return the models based on the search/filter conditions.
	 */
	public function search()
	{
		$criteria		 = new CDbCriteria;
		
		$criteria->compare('t.training_type_id', $this->training_type_id);
		$criteria->compare('t.title', $this->title, true);
		$criteria->compare('t.duration', $this->duration);
		$criteria->compare('t.lessons', $this->lessons);
		$criteria->compare('t.price', $this->price);

		return new CActiveDataProvider($this, array(
					'pagination' => array(
						'pageSize'	 => Yii::app()->user->getState('pageSize', Yii::app()->params['defaultPageSize']),
					),
					'criteria'	 => $criteria,
					'sort'		 => array(
						'attributes' => array(
							'*',
						),
					),
				));
	}

	public static function getDropdownList($withEmpty = false)
	{
		$models	 = self::model()->findAll();
		$list	 = array();
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
		$obj				 = new stdClass();
		$obj->fields		 = $this->attributeLabels();
		$obj->titleFields	 = array('title');
		$obj->title = 'Account';
		return $obj;
	}

	public function getModelDisplay()
	{
		return "{$this->training_type->name_en} - $this->title ";
	}

}
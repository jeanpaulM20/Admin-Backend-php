<?php

/**
 * @property integer $id	
 * @property string $name	
 */
class Exerciseset extends ActiveRecord
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
		return '{{exerciseset}}';
	}

	/**
	 * @return array validation rules for model attributes.
	 */
	public function rules()
	{
		// NOTE: you should only define rules for those attributes that
		// will receive user inputs.
		return array(
			array('id', 'numerical', 'integerOnly' => true),
			array('name', 'length', 'max' => 255),
			array('exercises, trainings, id, name, archive, published', 'safe'),
			array('exercises, trainings, id, name, archive, published', 'safe', 'on' => 'search'),
		);
	}

	/**
	 * @return array relational rules.
	 */
	public function relations()
	{
		return array(
			'reviews' => array(self::HAS_MANY, 'Review', 'exerciseset_id'),
			'exercises' => array(self::MANY_MANY, 'Exercise', 'tbl_exerciseset_exercise(exerciseset_id, exercise_id)'),
			'trainings' => array(self::MANY_MANY, 'Training', 'tbl_training_exerciseset(exerciseset_id, training_id)'),
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
			'id'	 => 'id',
			'name'	 => 'Name',
			'archive'	=> 'Archive',
			'published' => 'Publiched',
		);
	}
	
	public function getLocalizableAttributes()
	{
		return array(
			'name'
		);
	}

	/**
	 * Retrieves a list of models based on the current search/filter conditions.
	 * @return CActiveDataProvider the data provider that can return the models based on the search/filter conditions.
	 */
	public function search()
	{
		$criteria		 = new CDbCriteria;
		$criteria->with	 = array();
		$criteria->compare('t.id', $this->id);
		$criteria->compare('t.name', $this->name, true);

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
		$obj->titleFields	 = array('name');
		$obj->title = 'ExerciseSet';
		return $obj;
	}

	public function getModelDisplay()
	{
		return "$this->name ";
	}

}
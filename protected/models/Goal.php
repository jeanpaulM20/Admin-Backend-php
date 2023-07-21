<?php

/**
 * @property integer $id	
 * @property string $target	
 * @property string $description	
 * @property string $duration_total	
 * @property integer $achieved	
 * @property integer $client_id	
 */
class Goal extends ActiveRecord
{

	public $client_search;

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
		return '{{goal}}';
	}

	/**
	 * @return array validation rules for model attributes.
	 */
	public function rules()
	{
		// NOTE: you should only define rules for those attributes that
		// will receive user inputs.
		return array(
			array('client_id', 'required'),
			array('id, client_id', 'numerical', 'integerOnly' => true),
			array('target, duration_total', 'length', 'max' => 255),
			array('id, target, description, duration_total, achieved, client_id, client_search, trainings', 'safe'),
			array('id, target, description, duration_total, achieved, client_id, client_search, trainings', 'safe', 'on' => 'search'),
		);
	}

	/**
	 * @return array relational rules.
	 */
	public function relations()
	{
		return array(
			'client' => array(self::BELONGS_TO, 'Client', 'client_id'),
			'trainings' => array(self::MANY_MANY, 'Training', 'tbl_training_goal(goal_id, training_id)'),
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
			'id'			 => 'id',
			'target'		 => 'Target',
			'description'	 => 'Description',
			'duration_total' => 'Duration Total',
			'achieved'		 => 'achieved',
			'client_id'		 => 'Client',
			'client_search'	 => 'Client',
		);
	}
	
	public function getLocalizableAttributes()
	{
		return array(
			'target',
			'description'
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
		$criteria->compare('t.target', $this->target, true);
		$criteria->compare('t.description', $this->description);
		$criteria->compare('t.duration_total', Helper::parseDuration($this->duration_total));
		$criteria->compare('t.achieved', $this->achieved);
		$criteria->with[]	 = 'client';
		$client_search		 = new CDbCriteria;
		$client_search->compare('client.clientid', $this->client_search, true, 'OR');
		$client_search->compare('client.surname', $this->client_search, true, 'OR');
		$client_search->compare('client.name', $this->client_search, true, 'OR');
		$criteria->mergeWith($client_search);

		return new CActiveDataProvider($this, array(
					'pagination' => array(
						'pageSize'	 => Yii::app()->user->getState('pageSize', Yii::app()->params['defaultPageSize']),
					),
					'criteria'	 => $criteria,
					'sort'		 => array(
						'attributes' => array(
							'client_search' => array('asc'	 => 'client.clientid,client.surname,client.name', 'desc'	 => 'client.clientid DESC,client.surname DESC,client.name DESC',),
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
	
	public static function getDropdownListByClientId($client_id, $withEmpty = false)
	{
		$models	 = self::model()->findAllByAttributes(array('client_id' => $client_id));
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
		$obj->titleFields	 = array('target');
		$obj->title = 'Goal';
		return $obj;
	}

	public function getModelDisplay()
	{
		return "$this->target ";
	}
	
	public function updateDuration()
	{
		$duration = 0;
		foreach ($this->trainings as $training) {
			if ($training->status == 'attended') {
				$duration += $training->duration;
			}
		}
		$this->duration_total = $duration;
		$this->save();
	}
}
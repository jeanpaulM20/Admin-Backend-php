<?php

/**
 * @property integer $id	
 * @property string $status	
 * @property integer $client_id	
 */
class Account extends ActiveRecord
{

	public $date_of_joining_range = array();
	protected $status_values = array(
		'new'		 => 'new',
		'passive'	 => 'passive',
		'active'	 => 'active',
		'blocked'	 => 'blocked',
		'archive'	 => 'archive',
	);

	public function getStatusValues()
	{
		return $this->status_values;
	}

	public function getStatus()
	{
		if ($this->status) {
			return $this->status_values[$this->status];
		}
	}

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
		return '{{account}}';
	}

	/**
	 * @return array validation rules for model attributes.
	 */
	public function rules()
	{
		// NOTE: you should only define rules for those attributes that
		// will receive user inputs.
		return array(
			array('status', 'in', 'range'		 => array_keys($this->getStatusValues()), 'allowEmpty' => false),
			array('client_id', 'unique', 'message' => 'Please enter a diffrent value for {attribute}.'),
			array('id, client_id', 'numerical', 'integerOnly' => true),
			array('id, status, client_id, client_search, date_of_joining, date_of_joining_range, device, interval_distance, interval_repeats, interval_zone, running_zone', 'safe'),
			array('id, status, client_id, client_search, date_of_joining, date_of_joining_range, device, interval_distance, interval_repeats, interval_zone, running_zone', 'safe', 'on' => 'search'),
		);
	}

	/**
	 * @return array relational rules.
	 */
	public function relations()
	{
		return array(
			'client' => array(self::BELONGS_TO, 'Client', 'client_id'),
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
			'id'				 => 'id',
			'status'			 => 'status',
			'client_id'			 => 'Client',
			'client_search'		 => 'Client',
			'date_of_joining'	 => 'Date of joining',
			'date_of_joining_range' => 'Date of joining',
			'device' => 'Belt ID',
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
		$criteria->compare('t.status', $this->status);
		$criteria->compare('t.device', $this->device, true);
		
		$criteria->compare('t.interval_distance', $this->interval_distance);
		$criteria->compare('t.interval_repeats', $this->interval_repeats);
		$criteria->compare('t.interval_zone', $this->interval_zone);
		
		$criteria->with[]	 = 'client';
		$client_search		 = new CDbCriteria;
		$client_search->compare('client.clientid', $this->client_search, true, 'OR');
		$client_search->compare('client.surname', $this->client_search, true, 'OR');
		$client_search->compare('client.name', $this->client_search, true, 'OR');
		$criteria->mergeWith($client_search);


		$from	 = $to		 = '';
		if (count($this->date_of_joining_range) >= 1) {
			if (isset($this->date_of_joining_range['from'])) {
				$from = $this->date_of_joining_range['from'];
			}
			if (isset($this->date_of_joining_range['to'])) {
				$to = $this->date_of_joining_range['to'];
			}
		}
		if ($from != '' || $to != '') {
			if ($from != '') {
				$criteria->compare('t.date_of_joining', ">= $from", true);
			}
			if ($to != '') {
				$criteria->compare('t.date_of_joining_range', "< $to", true);
			}
		}

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

	public function getModelDescription()
	{
		$obj				 = new stdClass();
		$obj->fields		 = $this->attributeLabels();
		$obj->titleFields	 = array('status');
		$obj->title = 'Account';
		return $obj;
	}

	public function getModelDisplay()
	{
		return "$this->status ";
	}

}
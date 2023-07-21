<?php

class Locker extends ActiveRecord
{
	public $client_search;
	public $key_status;
	
	protected $gender_values = array(
		'm'				 => 'Male',
		'f'			 => 'Female',
	);

	public function getGenderValues()
	{
		return $this->gender_values;
	}

	public function getType()
	{
		if ($this->type) {
			return $this->gender_values[$this->type];
		}
	}
	
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
		return '{{locker}}';
	}

	public function scopes()
	{
		return array(
			'men' => array(
				'condition' => 'type="m"',
			),
			'women' => array(
				'condition' => 'type="f"',
			),
		);
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
			array('locker_id, type, status, client_id, training_id, key, key_request, request_num, admin_open', 'safe'),
			array('locker_id, type, status, client_id, training_id, key, key_request, request_num, admin_open', 'safe', 'on' => 'search'),
		);
	}

	/**
	 * @return array relational rules.
	 */
	public function relations()
	{
		return array(
			'client' => array(self::BELONGS_TO, 'Client', 'client_id'),
			'training' => array(self::BELONGS_TO, 'Training', 'training_id'),
		);
	}

	/*public function behaviors()
	{
		return array(
			'activerecord-relation' => array(
				'class' => 'ext.yiiext.behaviors.activerecord-relation.EActiveRecordRelationBehavior',
			));
	}*/

	/**
	 * @return array customized attribute labels (name=>label)
	 */
	public function attributeLabels()
	{
		return array(
			'id'			 => 'id',
			'client_id'		 => 'Assigned to',
			'training_id'		 => 'Appointment',
			'client_search'		 => 'Assigned to',
			'locker_id'		 => 'Locker ID',
			'type'			=> 'Wardrobe',
			'status'	=> 'Status'
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
		
		$criteria->compare('t.locker_id', $this->locker_id, true);
		$criteria->compare('t.type', $this->type);
		$criteria->compare('t.status', $this->status);

		$criteria->with[]			 = 'client';
		$client_search				 = new CDbCriteria;
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
						'defaultOrder'=>'length(locker_id), locker_id',
						'attributes' => array(
							'locker_id' => array('asc' => 'length(locker_id), locker_id', 'desc' => '100 - length(locker_id), locker_id DESC'),
							'client_search'	 => array('asc'				 => 'client.clientid,client.surname,client.name', 'desc'				 => 'client.clientid DESC,client.surname DESC,client.name DESC',),
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
		$obj->titleFields	 = array('locker_id');
		$obj->title = 'Locker';
		return $obj;
	}

	public function getModelDisplay()
	{
		return $this->locker_id;
	}

	public function approveKey()
	{
		$this->key = $this->key_request;
		$this->key_request = null;
		$this->request_num = 0;
		$this->save();
	}
	
	public function declineKey()
	{
		$this->key_request = null;
		$this->save();
	}
	
	public function release()
	{
		$this->client_id = null;
		$this->training_id = null;
		$this->save();
	}
	
	public function reserve($training)
	{
		$this->training_id = $training->id;
		$this->client_id = $training->client->id;
		$this->status = 'free';
		$this->save();
	}
}
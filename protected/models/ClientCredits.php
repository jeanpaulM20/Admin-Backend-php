<?php

class ClientCredits extends ActiveRecord
{

	public $client_search;
	public $price;
	public $abbonement_search;
	public $soldby_search;
	public $client_domicile_search;
	public $expires_range = array();
	public $startdate_range = array();
	public $sell_date_range = array();
	
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
		return '{{client_credits}}';
	}

	/**
	 * @return array validation rules for model attributes.
	 */
	public function rules()
	{
		// NOTE: you should only define rules for those attributes that
		// will receive user inputs.
		return array(
			array('client_id, training_type_id, sold_by', 'required'),
			array('id, client_id, training_type_id', 'numerical', 'integerOnly' => true),
			array('id, client_id, training_type_id, paid, attended, abbonement_id, expires, client_search, abbonement_search, sold_by_id, startdate, soldby_search, startdate_range, expires_range, sell_date_range, professional, training_target_1, training_target_2, acquisition, client_domicile_search, price', 'safe'),
			array('id, client_id, training_type_id, paid, attended, abbonement_id, expires, client_search, abbonement_search, sold_by_id, startdate, soldby_search, startdate_range, expires_range, sell_date_range, professional, training_target_1, training_target_2, acquisition, client_domicile_search, price', 'safe', 'on' => 'search'),
		);
	}

	/**
	 * @return array relational rules.
	 */
	public function relations()
	{
		return array(
			'client' => array(self::BELONGS_TO, 'Client', 'client_id'),
			'training_type' => array(self::BELONGS_TO, 'TrainingType', 'training_type_id'),
			'abbonement' => array(self::BELONGS_TO, 'Abbonement', 'abbonement_id'),
			'sold_by' => array(self::BELONGS_TO, 'Trainer', 'sold_by_id'),
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
			'client_id'		=> 'Client', 
			'training_type_id' => 'Training type', 
			'paid'	=> 'Credits paid', 
			'attended' => 'Sessions attended',
			'abbonement_id' => 'Abbonement',
			'client_search' => 'Client',
			'abbonement_search' => 'Abbonement',
			'sold_by_id' => 'Sold by',
			'soldby_search' => 'Sold by',
			'professional' => 'Professional', 
			'training_target_1' => 'Training Target I', 
			'training_target_2' => 'Training Target II', 
			'acquisition' => 'Acquisition',
			'client_domicile_search' => 'Client Domicile'
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
		
		$criteria->compare('t.client_id', $this->client_id);
		$criteria->compare('t.training_type_id', $this->training_type_id);
		$criteria->compare('t.paid', $this->paid);
		$criteria->compare('t.attended', $this->attended);
		
		$criteria->compare('t.professional', $this->professional, true);
		$criteria->compare('t.training_target_1', $this->training_target_1, true);
		$criteria->compare('t.training_target_2', $this->training_target_2, true);
		$criteria->compare('t.acquisition', $this->acquisition, true);
		
		
		
		$criteria->with[]			 = 'client';
		$client_search				 = new CDbCriteria;
		$client_search->compare('client.clientid', $this->client_search, true, 'OR');
		$client_search->compare('client.surname', $this->client_search, true, 'OR');
		$client_search->compare('client.name', $this->client_search, true, 'OR');
		$criteria->mergeWith($client_search);
		
		$criteria->compare('client.domicile', $this->client_domicile_search, true);
				
		$criteria->with[]			 = 'sold_by';
		$soldby_search				 = new CDbCriteria;
		$soldby_search->compare('sold_by.surname', $this->soldby_search, true, 'OR');
		$soldby_search->compare('sold_by.name', $this->soldby_search, true, 'OR');
		$criteria->mergeWith($soldby_search);
		
		$criteria->with[]			 = 'abbonement';
		$abbonement_search				 = new CDbCriteria;
		$abbonement_search->compare('abbonement.title', $this->abbonement_search);
		$criteria->mergeWith($abbonement_search);
		
		$from	 = $to		 = '';
		if (count($this->expires_range) >= 1) {
			if (isset($this->expires_range['from'])) {
				$from = $this->expires_range['from'];
			}
			if (isset($this->expires_range['to'])) {
				$to = $this->expires_range['to'];
			}
		}
		if ($from != '' || $to != '') {
			if ($from != '') {
				$criteria->compare('t.expires', ">= $from", true);
			}
			if ($to != '') {
				$criteria->compare('t.expires', "< $to", true);
			}
		}
		
		$from	 = $to		 = '';
		if (count($this->sell_date_range) >= 1) {
			if (isset($this->sell_date_range['from'])) {
				$from = $this->sell_date_range['from'];
			}
			if (isset($this->sell_date_range['to'])) {
				$to = $this->sell_date_range['to'];
			}
		}
		if ($from != '' || $to != '') {
			if ($from != '') {
				$criteria->compare('t.sell_date', ">= $from", true);
			}
			if ($to != '') {
				$criteria->compare('t.sell_date', "< $to", true);
			}
		}
		
		$from	 = $to		 = '';
		if (count($this->startdate_range) >= 1) {
			if (isset($this->startdate_range['from'])) {
				$from = $this->startdate_range['from'];
			}
			if (isset($this->startdate_range['to'])) {
				$to = $this->startdate_range['to'];
			}
		}
		if ($from != '' || $to != '') {
			if ($from != '') {
				$criteria->compare('t.startdate', ">= $from", true);
			}
			if ($to != '') {
				$criteria->compare('t.startdate', "< $to", true);
			}
		}
		
		return new CActiveDataProvider($this, array(
					'pagination' => array(
						'pageSize'	 => Yii::app()->user->getState('pageSize', Yii::app()->params['defaultPageSize']),
					),
					'criteria'	 => $criteria,
					'sort'		 => array(
						'attributes' => array(
							'soldby_search'	 => array('asc'				 => 'sold_by.surname,sold_by.name', 'desc'				 => 'sold_by.surname DESC,sold_by.name DESC',),
							'client_search'	 => array('asc'				 => 'client.clientid,client.surname,client.name', 'desc'				 => 'client.clientid DESC,client.surname DESC,client.name DESC',),
							'abbonement_search' => array('asc' => 'abbonement.title', 'desc' => 'abbonement.title DESC'),
							'client_domicile_search'  => array('asc' => 'client.domicile', 'desc' => 'client.domicile DESC'),
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
		$obj->titleFields	 = array('');
		$obj->title = 'Client Credits';
		return $obj;
	}

	public function getModelDisplay()
	{
		return "{$this->client->getModelDisplay()} {$this->training_type->name_en} {$this->attended}/{$this->paid}";
	}
	
	protected function beforeSave()
	{
		return true;
	}
}
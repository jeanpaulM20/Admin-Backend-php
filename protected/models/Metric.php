<?php

/**
 * @property integer $id	
 * @property string $name	
 * @property string $type	
 * @property string $group	
 * @property string $file	
 * @property string $data	
 * @property integer $client_id	
 */
class Metric extends ActiveRecord
{

	public $client_search;
	public $date_range = array();

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
		return '{{metric}}';
	}

	/**
	 * @return array validation rules for model attributes.
	 */
	public function rules()
	{
		// NOTE: you should only define rules for those attributes that
		// will receive user inputs.
		return array(
			array('client_id, date', 'required'),
			array('id, client_id', 'numerical', 'integerOnly' => true),
			array('id, client_id, client_search, date, weight, sys, dia, calm_pulse, body_fat_kg, body_fat_perc, waist_circumference, bcm', 'safe'),
			array('id, client_id, client_search, date, weight, sys, dia, calm_pulse, body_fat_kg, body_fat_perc, waist_circumference, bcm', 'safe', 'on' => 'search'),
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
			'id'			 => 'id',
			'client_id'		 => 'Client',
			'client_search'	 => 'Client',
			'date'	=> 'Date',
			'weight' => 'Weight',
			
			'waist_circumference' => 'Waist Circumference CM',
			'body_fat_kg' => 'Body Fat KG',
			'body_fat_perc' => 'Body Fat %',
			'bcm' => 'BCM KG',
			'sys' => 'Bloot pressure SYS',
			'dia' => 'Bloot pressure DIA',
			'calm_pulse' => 'Pulse at rest',
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
		//date_range
		$from	 = $to		 = '';
		if (count($this->date_range) >= 1) {
			if (isset($this->date_range['from'])) {
				$from = $this->date_range['from'];
			}
			if (isset($this->date_range['to'])) {
				$to = $this->date_range['to'];
			}
		}
		if ($from != '' || $to != '') {
			if ($from != '') {
				$criteria->compare('t.date', ">= $from", true);
			}
			if ($to != '') {
				$criteria->compare('t.date', "< $to", true);
			}
		}
		$criteria->compare('t.weight', $this->weight);
		$criteria->compare('t.sys', $this->sys);
		$criteria->compare('t.dia', $this->dia);
		$criteria->compare('t.calm_pulse', $this->calm_pulse);
		$criteria->compare('t.body_fat_kg', $this->body_fat_kg);
		$criteria->compare('t.body_fat_perc', $this->body_fat_perc);
		
		$criteria->compare('t.waist_circumference', $this->waist_circumference);
		$criteria->compare('t.bcm', $this->bcm);
		
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
	
	protected function beforeSave()
	{
		$this->date		 = date('Y-m-d', strtotime($this->date));
		return parent::beforeSave();
	}
	
	protected function afterFind()
	{
		$this->date		 = strtotime($this->date) ? date('d.m.Y', strtotime($this->date)) : '';
		parent::afterFind();
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
		$obj->titleFields	 = array('date');
		$obj->title = 'Metric';
		return $obj;
	}

	public function getModelDisplay()
	{
		return $this->client->getModelDisplay() . " " . $this->date;
	}

}
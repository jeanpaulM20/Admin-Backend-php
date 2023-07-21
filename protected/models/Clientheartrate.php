<?php

/**
 * @property integer $id	
 * @property string $token	
 * @property string $date	
 * @property integer $client_id	
 */
class Clientheartrate extends ActiveRecord
{

	public $date_range = array();
	public $client_search;

	public function defaultScope()
	{
		return array(
			'order' => 'date desc',
		);
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
		return '{{client_heart_rate}}';
	}

	/**
	 * @return array validation rules for model attributes.
	 */
	public function rules()
	{
		// NOTE: you should only define rules for those attributes that
		// will receive user inputs.
		return array(
			array('client_id, max, min', 'required'),
			array('id, client_id', 'numerical', 'integerOnly' => true),
			array('id, max, min, date, date_range, client_id, client_search', 'safe'),
			array('id, max, min, date, date_range, client_id, client_search', 'safe', 'on' => 'search'),
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
			'max' => 'Max heart rate',
			'min' => 'Min heart rate',
			'date'			 => 'Date',
			'date_range'	 => 'Date',
			'client_id'		 => 'Client',
			'client_search'	 => 'Client',
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
		$criteria->compare('t.max', $this->max);
		$criteria->compare('t.min', $this->min);
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
		$criteria->with[]	 = 'client';
		$client_search		 = new CDbCriteria;
		$client_search->compare('client.id', $this->client_search, true, 'OR');
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
							'client_search' => array('asc'	 => 'client.id,client.surname,client.name', 'desc'	 => 'client.id DESC,client.surname DESC,client.name DESC',),
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
		$obj->titleFields	 = array('id');
		$obj->title = 'Client heart rates';
		return $obj;
	}

	public function getModelDisplay()
	{
		return "$this->date: max $this->max min $this->min";
	}

}
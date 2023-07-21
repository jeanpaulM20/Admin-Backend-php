<?php

/**
 * @property integer $id	
 * @property integer $preferred_trainer_rel	
 * @property integer $preferred_language_rel	
 * @property integer $preferred_location_rel	
 * @property integer $client_id	
 */
class Preference extends ActiveRecord
{

	public $preferred_trainer_search;
	public $preferred_language_search;
	public $preferred_location_search;
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
		return '{{preference}}';
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
			array('client_id', 'unique', 'message' => 'Please enter a diffrent value for {attribute}.'),
			array('id, preferred_trainer_rel, preferred_language_rel, preferred_location_rel, client_id, auto_send_appointement', 'numerical', 'integerOnly' => true),
			array('id, preferred_trainer_rel, preferred_trainer_search, preferred_language_rel, preferred_language_search, preferred_location_rel, preferred_location_search, client_id, client_search, auto_send_appointement', 'safe'),
			array('id, preferred_trainer_rel, preferred_trainer_search, preferred_language_rel, preferred_language_search, preferred_location_rel, preferred_location_search, client_id, client_search, auto_send_appointement', 'safe', 'on' => 'search'),
		);
	}

	/**
	 * @return array relational rules.
	 */
	public function relations()
	{
		return array(
			'client' => array(self::BELONGS_TO, 'Client', 'client_id'),
			'preferred_trainer' => array(self::BELONGS_TO, 'Trainer', 'preferred_trainer_rel'),
			'preferred_language' => array(self::BELONGS_TO, 'Language', 'preferred_language_rel'),
			'preferred_location' => array(self::BELONGS_TO, 'Location', 'preferred_location_rel'),
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
			'id'						 => 'id',
			'preferred_trainer_rel'		 => 'Preferred trainer',
			'preferred_trainer_search'	 => 'Preferred trainer',
			'preferred_language_rel'	 => 'Preferred language',
			'preferred_language_search'	 => 'Preferred language',
			'preferred_location_rel'	 => 'Preferred location',
			'preferred_location_search'	 => 'Preferred location',
			'client_id'					 => 'Client',
			'client_search'				 => 'Client',
			'auto_send_appointement'	=> 'Auto send appointement',
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
		$criteria->with[]			 = 'preferred_trainer';
		$preferred_trainer_search	 = new CDbCriteria;
		$preferred_trainer_search->compare('preferred_trainer.surname', $this->preferred_trainer_search, true, 'OR');
		$preferred_trainer_search->compare('preferred_trainer.name', $this->preferred_trainer_search, true, 'OR');
		$criteria->mergeWith($preferred_trainer_search);
		$criteria->with[]			 = 'preferred_language';
		$preferred_language_search	 = new CDbCriteria;
		$preferred_language_search->compare('preferred_language.language', $this->preferred_language_search, true, 'OR');
		$criteria->mergeWith($preferred_language_search);
		$criteria->with[]			 = 'preferred_location';
		$preferred_location_search	 = new CDbCriteria;
		$preferred_location_search->compare('preferred_location.name', $this->preferred_location_search, true, 'OR');
		$criteria->mergeWith($preferred_location_search);
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
						'attributes' => array(
							'preferred_trainer_search' => array('asc'						 => 'preferred_trainer.surname,preferred_trainer.name', 'desc'						 => 'preferred_trainer.surname DESC,preferred_trainer.name DESC',),
							'preferred_language_search'	 => array('asc'						 => 'preferred_language.language', 'desc'						 => 'preferred_language.language DESC',),
							'preferred_location_search'	 => array('asc'			 => 'preferred_location.name', 'desc'			 => 'preferred_location.name DESC',),
							'client_search'	 => array('asc'	 => 'client.clientid,client.surname,client.name', 'desc'	 => 'client.clientid DESC,client.surname DESC,client.name DESC',),
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
		$obj->title = 'Preference';
		return $obj;
	}

	public function getModelDisplay()
	{
		return "$this->id ";
	}

}
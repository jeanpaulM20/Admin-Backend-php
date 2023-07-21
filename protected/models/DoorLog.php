<?php

class DoorLog extends ActiveRecord
{

	const NO_ACCESS = 'access denied';
	const OPEN_DOOR = 'open door';

	public $client_search;
	public $trainer_search;
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
		return '{{door_log}}';
	}

	/**
	 * @return array validation rules for model attributes.
	 */
	public function rules()
	{
		// NOTE: you should only define rules for those attributes that
		// will receive user inputs.
		return array(
			array('id, client_id, trainer_id, date, action, comment', 'safe'),
			array('id, client_id, trainer_id, date, action, comment', 'safe', 'on' => 'search'),
		);
	}

	/**
	 * @return array relational rules.
	 */
	public function relations()
	{
		return array(
			'client' => array(self::BELONGS_TO, 'Client', 'client_id'),
			'trainer' => array(self::BELONGS_TO, 'Trainer', 'trainer_id'),
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
			'trainer_id'		 => 'Trainer',
			'trainer_search'	 => 'Trainer',
			'client_id'		 => 'Client',
			'client_search'	 => 'Client',
			'date'			=> 'Date',
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
		$client_search->compare('client.clientid', $this->client_search, true, 'OR');
		$client_search->compare('client.surname', $this->client_search, true, 'OR');
		$client_search->compare('client.name', $this->client_search, true, 'OR');
		$criteria->mergeWith($client_search);

		$criteria->with[]	 = 'trainer';
		$trainer_search = new CDbCriteria;
		$trainer_search->compare('trainer.surname', $this->trainer_search, true,'OR');
		$trainer_search->compare('trainer.name', $this->trainer_search, true,'OR');
		$criteria->mergeWith($trainer_search);

		return new CActiveDataProvider($this, array(
					'pagination' => array(
						'pageSize'	 => Yii::app()->user->getState('pageSize', Yii::app()->params['defaultPageSize']),
					),
					'criteria'	 => $criteria,
					'sort'		 => array(
						'attributes' => array(
							'client_search' => array('asc'	 => 'client.clientid,client.surname,client.name', 'desc'	 => 'client.clientid DESC,client.surname DESC,client.name DESC',),
							'trainer_search' => array('asc'	 => 'trainer.name, trainer.surname', 'desc'	 => 'trainer.name DESC, trainer.surname DESC',),
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

	public static function logRefusal($comment = '')
	{
		$model = new DoorLog;
		$model->action = DoorLog::NO_ACCESS;
		$model->comment = $comment;
		$model->save();
	}

	public static function logActionClient($client_id, $action = DoorLog::OPEN_DOOR, $comment = '')
	{
		$model = new DoorLog;
		$model->client_id = $client_id;
		$model->action = $action;
		$model->comment = $comment;
		$model->save();
	}
	public static function logActionTrainer($trainer_id, $action = DoorLog::OPEN_DOOR, $comment = '')
	{
		$model = new DoorLog;
		$model->trainer_id = $trainer_id;
		$model->action = $action;
		$model->comment = $comment;
		$model->save();
	}
}

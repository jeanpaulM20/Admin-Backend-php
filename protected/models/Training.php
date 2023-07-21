<?php

/**
 * @property integer $id	
 * @property string $date	
 * @property string $starttime	
 * @property string $duration
 * @property string $type	
 * @property string $text	
 * @property string $status	
 * @property string $cancelled_at	
 * @property integer $cancelled_by_client_rel	
 * @property integer $cancelled_by_trainer_rel	
 * @property integer $client_id	
 * @property integer $location_id	
 * @property integer $trainer_id	
 */
Yii::import('application.extensions.ical.iCalcreator', true);
class Training extends ActiveRecord
{

	protected $_oldAttrbiutes = array();
	
	public $date_range = array();
	public $no_email = false;

	protected $status_values = array(
		'attended'	 => 'attended',
		'booked'	 => 'booked',
		'cancelled'	 => 'cancelled',
		'missed'	 => 'missed',
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

	public $cancelled_at_range = array();
	public $cancelled_by_client_search;
	public $cancelled_by_trainer_search;
	public $client_search;
	public $location_search;
	public $trainer_search;

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
		return '{{training}}';
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
			array('client_id, type_id', 'required'),
			array('starttime', 'avaliable'),
			array('id, cancelled_by_client_rel, cancelled_by_trainer_rel, client_id, location_id, trainer_id, duration', 'numerical', 'integerOnly' => true),
			array('exercisesets, id, date, date_range, starttime, duration, type_id, text, status, cancelled_at, cancelled_at_range, cancelled_by_client_rel, cancelled_by_client_search, cancelled_by_trainer_rel, cancelled_by_trainer_search, client_id, client_search, location_id, location_search, trainer_id, trainer_search, credits_charged', 'safe'),
			array('exercisesets, id, date, date_range, starttime, duration, type_id, text, status, cancelled_at, cancelled_at_range, cancelled_by_client_rel, cancelled_by_client_search, cancelled_by_trainer_rel, cancelled_by_trainer_search, client_id, client_search, location_id, location_search, trainer_id, trainer_search, credits_charged', 'safe', 'on' => 'search'),
		);
	}

	/**
	 * @return array relational rules.
	 */
	public function relations()
	{
		return array(
			'trainer' => array(self::BELONGS_TO, 'Trainer', 'trainer_id'),
			'reviews' => array(self::HAS_MANY, 'Review', 'training_id'),
			'exercisesets' => array(self::MANY_MANY, 'Exerciseset', 'tbl_training_exerciseset(training_id, exerciseset_id)'),
//			'goals' => array(self::MANY_MANY, 'Goal', 'tbl_training_goal(training_id, goal_id)'),
			'client' => array(self::BELONGS_TO, 'Client', 'client_id'),
			'location' => array(self::BELONGS_TO, 'Location', 'location_id'),
			'cancelled_by_client' => array(self::BELONGS_TO, 'Client', 'cancelled_by_client_rel'),
			'cancelled_by_trainer' => array(self::BELONGS_TO, 'Trainer', 'cancelled_by_trainer_rel'),
			'type' => array(self::BELONGS_TO, 'TrainingType', 'type_id'),
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
			'id'							 => 'id',
			'date'							 => 'Date',
			'date_range'					 => 'Date',
			'starttime'						 => 'Starttime',
			'duration'						 => 'Duration',
			'type_id'							 => 'Type',
			'text'							 => 'Text',
			'status'						 => 'Status',
			'cancelled_at'					 => 'Cancelled at',
			'cancelled_at_range'			 => 'Cancelled at',
			'cancelled_by_client_rel'		 => 'Cancelled by client',
			'cancelled_by_client_search'	 => 'Cancelled by client',
			'cancelled_by_trainer_rel'		 => 'Cancelled by trainer',
			'cancelled_by_trainer_search'	 => 'Cancelled by trainer',
			'client_id'						 => 'Client',
			'client_search'					 => 'Client',
			'location_id'					 => 'Location',
			'location_search'				 => 'Location',
			'trainer_id'					 => 'Trainer',
			'trainer_search'				 => 'Trainer',
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
		$criteria->compare('t.starttime', $this->starttime);
		$criteria->compare('t.duration', $this->duration);
		$criteria->compare('t.type_id', $this->type_id);
		$criteria->compare('t.text', $this->text);
		$criteria->compare('t.status', $this->status);
		//cancelled_at_range
		$from	 = $to		 = '';
		if (count($this->cancelled_at_range) >= 1) {
			if (isset($this->cancelled_at_range['from'])) {
				$from = $this->cancelled_at_range['from'];
			}
			if (isset($this->cancelled_at_range['to'])) {
				$to = $this->cancelled_at_range['to'];
			}
		}
		if ($from != '' || $to != '') {
			if ($from != '') {
				$criteria->compare('t.cancelled_at', ">= $from", true);
			}
			if ($to != '') {
				$criteria->compare('t.cancelled_at', "< $to", true);
			}
		}
		$criteria->with[]			 = 'cancelled_by_client';
		$cancelled_by_client_search	 = new CDbCriteria;
		$cancelled_by_client_search->compare('cancelled_by_client.clientid', $this->cancelled_by_client_search, true, 'OR');
		$cancelled_by_client_search->compare('cancelled_by_client.surname', $this->cancelled_by_client_search, true, 'OR');
		$cancelled_by_client_search->compare('cancelled_by_client.name', $this->cancelled_by_client_search, true, 'OR');
		$criteria->mergeWith($cancelled_by_client_search);
		$criteria->with[]			 = 'cancelled_by_trainer';
		$cancelled_by_trainer_search = new CDbCriteria;
		$cancelled_by_trainer_search->compare('cancelled_by_trainer.surname', $this->cancelled_by_trainer_search, true, 'OR');
		$cancelled_by_trainer_search->compare('cancelled_by_trainer.name', $this->cancelled_by_trainer_search, true, 'OR');
		$criteria->mergeWith($cancelled_by_trainer_search);
		$criteria->with[]			 = 'client';
		$client_search				 = new CDbCriteria;
		$client_search->compare('client.clientid', $this->client_search, true, 'OR');
		$client_search->compare('client.surname', $this->client_search, true, 'OR');
		$client_search->compare('client.name', $this->client_search, true, 'OR');
		$criteria->mergeWith($client_search);
		$criteria->with[]			 = 'location';
		$location_search			 = new CDbCriteria;
		$location_search->compare('location.name', $this->location_search, true, 'OR');
		$criteria->mergeWith($location_search);
		$criteria->with[]			 = 'trainer';
		$trainer_search				 = new CDbCriteria;
		$trainer_search->compare('trainer.surname', $this->trainer_search, true, 'OR');
		$trainer_search->compare('trainer.name', $this->trainer_search, true, 'OR');
		$criteria->mergeWith($trainer_search);

		return new CActiveDataProvider($this, array(
					'pagination' => array(
						'pageSize'	 => Yii::app()->user->getState('pageSize', Yii::app()->params['defaultPageSize']),
					),
					'criteria'	 => $criteria,
					'sort'		 => array(
						'attributes' => array(
							'cancelled_by_client_search' => array('asc'							 => 'cancelled_by_client.clientid,cancelled_by_client.surname,cancelled_by_client.name', 'desc'							 => 'cancelled_by_client.clientid DESC,cancelled_by_client.surname DESC,cancelled_by_client.name DESC',),
							'cancelled_by_trainer_search'	 => array('asc'			 => 'cancelled_by_trainer.surname,cancelled_by_trainer.name', 'desc'			 => 'cancelled_by_trainer.surname DESC,cancelled_by_trainer.name DESC',),
							'client_search'	 => array('asc'				 => 'client.clientid,client.surname,client.name', 'desc'				 => 'client.clientid DESC,client.surname DESC,client.name DESC',),
							'location_search'	 => array('asc'			 => 'location.name', 'desc'			 => 'location.name DESC',),
							'trainer_search' => array('asc'	 => 'trainer.surname,trainer.name', 'desc'	 => 'trainer.surname DESC,trainer.name DESC',),
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
		$obj->titleFields	 = array('date', 'starttime', 'duration');
		$obj->title = 'Training';
		return $obj;
	}

	public function getModelDisplay()
	{
		return date('d.m.Y', strtotime($this->date)) . ' - ' . date('H:i', strtotime($this->starttime)) . ' - ' . date('H:i', strtotime($this->getEndTime()));
	}

	protected function beforeSave()
	{
		$this->date		 = date('Y-m-d', strtotime($this->date));
		$this->starttime = date('H:i:s', strtotime($this->starttime));
		return parent::beforeSave();
	}

	public function cancel($actor)
	{
		$this->status		 = 'cancelled';
		$this->cancelled_at	 = date('Y-m-d');
		if ($actor instanceof Client) {
			$this->cancelled_by_client = $actor->id;
		} else {
			$this->cancelled_by_trainer = $actor->id;
		}
		if (strtotime("+12hours") > strtotime($this->date . ' ' . $this->starttime) && !$this->credits_charged) {
			$this->client->markCredit($this->type_id);
		}
		if ($this->save() && $this->client->e_mail) {
			$this->sendTrainingEmail();
		}
	}

	protected $_icalStatuses = array(
		'attended'	 => 'CONFIRMED',
		'booked'	 => 'CONFIRMED',
		'missed'	 => 'CANCELLED',
		'cancelled'	 => 'CANCELLED'
	);

	public function getIcalStatus()
	{
		return $this->_icalStatuses[$this->status];
	}

	/*
	 * in minutes
	 */

	public function getDuration()
	{
		return $this->type->duration ? $this->type->duration : $this->duration;
	}
	
	public function getEndTime()
	{
		return date('H:i:s', strtotime('+' . $this->getDuration() . 'minutes', strtotime($this->starttime)));
	}

	public function asICalEvent($v)
	{

		$e = $v->newComponent('VEVENT');

		$e->setUid($this->id . '@' . $e->getConfig('unique_id'));

		$e->setProperty('categories', 'HEALTH');
		$date	 = strtotime($this->date);
		$start	 = strtotime($this->starttime);
		$e->setProperty('dtstart', date('Y', $date), date('m', $date), date('d', $date), date('H', $start), date('i', $start), 00);
		$e->setProperty('duration', 0, 0, 0, $this->getDuration());
		$e->setProperty('summary', $this->type->name_en . ' ' . $this->getModelDisplay());
		$e->setProperty('status', $this->getIcalStatus());

		$e->setOrganizer($this->trainer->e_mail, array('CN' => $this->trainer->surname . ' ' . $this->trainer->name));
		$e->setAttendee($this->client->e_mail, array('CN' => $this->client->surname . ' ' . $this->client->name));

		$e->setProperty('location', $this->location->name);
		if ($this->location->latitude && $this->location->longitude) {
			$e->setGeo($this->location->latitude, $this->location->longitude);
		}
		$e->setClass('PUBLIC');
		return $e;
	}

	protected function afterSave()
	{
		if ($this->isNewRecord && $this->client->preference->auto_send_appointement && $this->client->e_mail && !$this->no_email) {
			$this->sendTrainingEmail();
		}
		parent::afterSave();
//		unset($this->goals);
//		foreach ($this->goals as $goal) {
//			$goal->updateDuration();
//		}
		
	}
	
	protected function afterFind()
	{
		$this->_oldAttrbiutes = $this->attributes;
		if (!$this->duration) {
			$this->duration = $this->getDuration();
		}
		parent::afterFind();
	}
	
	public function ical() {
		$v = new vcalendar(array('unique_id'  => 'sihltraining'));
		$v->setMethod('REQUEST');
		$e  = $this->asICalEvent($v);
		$e->setDescription($this->text);

		$alarm = $e->newComponent('valarm');
		$alarm->setAction('DISPLAY');
		$alarm->setDescription('REMINDER');
		$alarm->setTrigger('-PT15M', array('RELATED' => true));
		return $v;
	}

	protected function sendTrainingEmail()
	{
		$message			 = new YiiMailMessage;
		$body				 = "Time: {$this->getModelDisplay()}<br/>Ort: {$this->location->name}<br/><br/>" . $this->text;
		$message->setBody($body, 'text/html');
		$message->subject	 = $this->type->name_en . ' - ' . $this->getModelDisplay() . ($this->status == 'cancelled' ? ' (Canceled)' : '');
		$message->addTo($this->client->e_mail);
		$message->from		 = Yii::app()->params['adminEmail'];

		$v = $this->ical();

		$attachment = Swift_Attachment::newInstance()
				->setFilename('invite.ics')
				->setContentType('text/calendar')
				->setBody($v->createCalendar())
		;
		$message->attach($attachment);
		Yii::app()->mail->send($message);
	}
	
	public function avaliable($attribute,$params)
	{	
		if (!$this->checkAvalible()) {
			$this->addError($attribute, 'Trainer is not avaliable on this time');
		}
	}
	
	public function checkAvalible() {
		if ($this->id || !$this->trainer_id || !$this->date || !$this->starttime) return true;
		if ($this->type->no_avaliability) return true;
		$this->date		 = date('Y-m-d', strtotime($this->date));
		$this->starttime = date('H:i:s', strtotime($this->starttime));
		
		$availability = $this->trainer->getLocationAvailability($this->location_id, $this->date, $this->date);
		$isAvalible = false;
		$start = strtotime($this->date . ' ' . $this->starttime);
		$end = $start + ($this->getDuration() * 60);
		$type_id = $this->type_id;
		if ($this->type->avaliability_from) {
			$type_id = $this->type->avaliability_from;
		}
		
		foreach ($availability as $value) {
			if ($type_id != $value['training_type_id']) continue;
			$avStart = strtotime($value['date'] . ' ' . $value['from']);
					$avEnd = strtotime($value['date'] . ' ' . $value['to']);
			if ($start >= $avStart && $end <= $avEnd) {
				$isAvalible = true;
			}
		} 
		return $isAvalible;
	}
	
	public function getNextTraining($trainer_id = null) {
		$training_id_query = Yii::app()->db->createCommand()
				->select('id')
				->from('tbl_training')
				->where('status="booked" and (date > :date or (date = :date and starttime >= :time))', array('date' => date('Y-m-d'), 'time' => date('H:i:s')));
		if ($trainer_id) {
			$training_id_query->where('trainer_id = ?', $trainer_id);
		}
		$training_id_query->order(array('date asc', 'starttime asc'));
		$training_id = $training_id_query->queryRow();
		if ($training_id) {
			return Training::model()->findByPk($training_id['id']);
		} else {
			return false;
		}
	}
	
	public static function getNextTrainingByClient($client_id) {
		$training_id_query = Yii::app()->db->createCommand()
				->select('id')
				->from('tbl_training')
				->where('status="booked" and (date > :date or (date = :date and starttime >= :time)) and client_id = :client_id', array('date' => date('Y-m-d'), 'time' => date('H:i:s'), 'client_id' => $client_id));
		$training_id_query->order(array('date asc', 'starttime asc'));
		$training_id = $training_id_query->queryRow();
		if ($training_id) {
			return Training::model()->findByPk($training_id['id']);
		} else {
			return false;
		}
	}
}
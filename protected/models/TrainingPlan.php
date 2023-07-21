<?php

/**
 * @property integer $id	
 * @property integer $client_id	
 */
class TrainingPlan extends ActiveRecord
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
	
	public static function getTypeValues()
	{
		return array(
			'strength' => 'Kraft', 
			'speed' => 'Schnelligkeit', 
			'endurance' => 'Ausdauer', 
			'sensorimotor' => 'Sensomotorisch'
		);
	}
	
	public function getType()
	{
		$values = self::getTypeValues();
		if (isset($values[$this->type])) {
			return $values[$this->type];
		} else {
			return '';
		}
	}

	/**
	 * @return string the associated database table name
	 */
	public function tableName()
	{
		return '{{trainingplan}}';
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
			array('id, client_id, client_search, reviews, load_duration, repeat, temp, rates, phase, personal_week, own_week, goal, values, new_pro,type', 'safe'),
			array('id, client_id, client_search, reviews, load_duration, repeat, temp, rates, phase, personal_week, own_week, goal, values, new_pro,type', 'safe', 'on' => 'search'),
		);
	}

	/**
	 * @return array relational rules.
	 */
	public function relations()
	{
		return array(
			'client' => array(self::BELONGS_TO, 'Client', 'client_id'),
			'review' => array(self::HAS_MANY, 'Review', 'trainingplan_id'),
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
			'client_id'		 => 'Vorname/Name',
			'client_search'	 => 'Vorname/Name',
			'load_duration' => 'Belastungsdauer', 
			'repeat' => 'Wiederholung',
			'temp' => 'Tempo',
			'rates' => 'S&auml;tze',
			'phase' => 'Phase',
			'personal_week' => 'Personal Training / Week',
			'own_week' => 'Eigenes T. / Week',
			'goal' => 'Ziel',
			'values' => '',
			'new_pro' => 'Neues Pro.',
			'type' => 'Type',
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
		
		$criteria->compare('t.load_duration', $this->load_duration);
		$criteria->compare('t.repeat', $this->repeat);
		$criteria->compare('t.temp', $this->temp);
		$criteria->compare('t.rates', $this->rates);
		$criteria->compare('t.phase', $this->phase);
		$criteria->compare('t.personal_week', $this->personal_week);
		$criteria->compare('t.own_week', $this->own_week);
		$criteria->compare('t.goal', $this->goal);
		$criteria->compare('t.new_pro', $this->new_pro);
		$criteria->compare('t.type', $this->type);
		
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
		$obj->title = 'TrainingPlan';
		return $obj;
	}

	public function getModelDisplay()
	{
		return $this->new_pro;
	}
	
	protected function beforeSave()
	{
		if (is_array($this->values)) {
			$this->values = json_encode($this->values);
		}
		return parent::beforeSave();
	}
	
	public function getValues() {
		if (is_array($this->values)) {
			return $this->values;
		} else if (is_string($this->values)) {
			return json_decode($this->values, true);
		} else {
			$result = array(
				'sonsomo' => array(),
				'main' => array(),
				'core' => array(),
				'dates' => array()
			);
			$rowTemplate = array(
				'exercise' => '',
				'device' => '',
				'position' => '',
				'weight' => '',
				'dates' => array()
			);
			for ($i=0; $i < 3; $i++) {
				$result['sonsomo'][] = $rowTemplate;
			}
			for ($i=0; $i < 6; $i++) {
				$result['main'][] = $rowTemplate;
			}
			for ($i=0; $i < 3; $i++) {
				$result['core'][] = $rowTemplate;
			}
			return $result;
		}
	}
}
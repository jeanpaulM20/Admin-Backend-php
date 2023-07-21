<?php

class PerformanceTest extends ActiveRecord
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
		return '{{performance_test}}';
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
			array('id, client_id, client_search, date, straight_thigh_extensors, points, hamstrings, calfs, adductors, pullups, trunk_bending, pushups, forearm_support, side_support,squat_on_wall,  sensomotoric, symmetry, reaction, counter_movement_jump, tapping, sprint_10, sprint_20, sprint_30', 'safe'),
			array('id, client_id, client_search, date, straight_thigh_extensors, points, hamstrings, calfs, adductors, pullups, trunk_bending, pushups, forearm_support, side_support,squat_on_wall, sensomotoric, symmetry, reaction, counter_movement_jump, tapping, sprint_10, sprint_20, sprint_30', 'safe', 'on' => 'search'),
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
			'points' => 'Stabilität',
//			'hip_flexor' => 'Hüftbeuger',
			'hamstrings' => 'Nackenmuskulatur',
			'calfs' => 'Wadenmuskulatur',
			'adductors' => 'Rückenstrecker',
			'pullups' => 'Klimmzug',
			'trunk_bending' => 'Rumpfbeugen',
//			'raise_up' => 'Aufrichten',
			'pushups' => 'Liegestütze',
			'forearm_support' => 'Unterarmstützen',
			'side_support' => 'Seitestützen',
			'squat_on_wall' => 'Hocke an Wand',
//			'large_chest_muscle' => 'Grosser Brustmuskel',
//			'straight_thigh_extensors' => 'Gerade Oberschenkelstrecker',
			'sensomotoric' => 'Sensomotorik',
			'symmetry' => 'Symmetrie',
			'reaction' => 'Reaktion',
			'counter_movement_jump' => 'Counter Movement Jump',
			'tapping' => 'Tapping',
			'sprint_10' => '10m Sprint',
			'sprint_20' => '20m Sprint',
			'sprint_30' => '30m Sprint',
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
		$criteria->compare('t.points', $this->points);
		$criteria->compare('t.hamstrings', $this->hamstrings);
		$criteria->compare('t.calfs', $this->calfs);
		$criteria->compare('t.adductors', $this->adductors);
		$criteria->compare('t.pullups', $this->pullups);
		$criteria->compare('t.trunk_bending', $this->trunk_bending);
		$criteria->compare('t.pushups', $this->pushups);
		$criteria->compare('t.forearm_support', $this->forearm_support);
		$criteria->compare('t.side_support', $this->side_support);
		$criteria->compare('t.squat_on_wall', $this->squat_on_wall);
		$criteria->compare('t.sensomotoric', $this->sensomotoric);
		$criteria->compare('t.symmetry', $this->symmetry);
		$criteria->compare('t.reaction', $this->reaction);
		$criteria->compare('t.counter_movement_jump', $this->counter_movement_jump);
		$criteria->compare('t.tapping', $this->tapping);
		$criteria->compare('t.sprint_10', $this->sprint_10);
		$criteria->compare('t.sprint_20', $this->sprint_20);
		$criteria->compare('t.sprint_30', $this->sprint_30);
		
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
		$this->date		 = date('Y-m-d H:i:s', strtotime($this->date));
		return parent::beforeSave();
	}
	
	protected function afterFind()
	{
		$this->date		 = strtotime($this->date) ? date('d.m.Y H:i:s', strtotime($this->date)) : '';
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
		$obj->title = 'Performance Test';
		return $obj;
	}

	public function getModelDisplay()
	{
		return $this->client->getModelDisplay() . " " . $this->date;
	}

}
<?php

class Screenstats extends ActiveRecord
{
	public $date_range = array();
	public $locker_search = null;
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
		return '{{screen_stats}}';
	}

	/**
	 * @return array validation rules for model attributes.
	 */
	public function rules()
	{
		// NOTE: you should only define rules for those attributes that
		// will receive user inputs.
		return array(
			array('locker_id, screen, time, visits, clicks, subclicks', 'safe'),
			array('locker_id, screen, time, visits, clicks, subclicks', 'safe', 'on' => 'search'),
		);
	}

	/**
	 * @return array relational rules.
	 */
	public function relations()
	{
		return array(
			'locker' => array(self::BELONGS_TO, 'Locker', 'locker_id'),
		);
	}

	/**
	 * @return array customized attribute labels (name=>label)
	 */
	public function attributeLabels()
	{
		return array(
			'date' => 'Date',
			'locker_id' => 'Locker',
			'locker_search' => 'Locker',
			'screen' => 'Screen name',
			'time' => 'Total time',
			'visits' => 'Visits',
			'clicks' => 'Clicks',
			'subclicks' => 'Subclicks',
		);
	}

	/**
	 * Retrieves a list of models based on the current search/filter conditions.
	 * @return CActiveDataProvider the data provider that can return the models based on the search/filter conditions.
	 */
	public function search()
	{
		$criteria		 = new CDbCriteria;
		$criteria->with	 = array('locker');
		$criteria->compare('t.id', $this->id);

		$criteria->compare('t.screen', $this->screen, true);
		$criteria->compare('t.time', $this->time);
		$criteria->compare('t.visits', $this->visits);
		$criteria->compare('t.clicks', $this->clicks);
		$criteria->compare('t.subclicks', $this->subclicks);
		
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
		
		$locker_search		 = new CDbCriteria;
		$locker_search->compare('locker.locker_id', $this->locker_search, true);
		$criteria->mergeWith($locker_search);


		return new CActiveDataProvider($this, array(
					'pagination' => array(
						'pageSize'	 => Yii::app()->user->getState('pageSize', Yii::app()->params['defaultPageSize']),
					),
					'criteria'	 => $criteria,
					'sort'		 => array(
						'attributes' => array(
							'locker_search' => array('asc'	 => 'locker.locker_id', 'desc'	 => 'locker.locker_id DESC',),
							'*',
						),
					),
				));
	}
	
	public function getModelDisplay() {
		return $this->locker->locker_id . ' ' . $this->screen;
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
}

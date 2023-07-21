<?php

class TrainingType extends ActiveRecord
{

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
		return '{{training_type}}';
	}

	/**
	 * @return array validation rules for model attributes.
	 */
	public function rules()
	{
		// NOTE: you should only define rules for those attributes that
		// will receive user inputs.
		return array(
			array('name_en, name_de', 'required'),
			array('id', 'numerical', 'integerOnly' => true),
			array('name_en, name_de', 'length', 'max' => 255),
			array('id, name_en, name_de, duration, participants, no_avaliability, avaliability_from, credits_from, sort, service, no_locker, abbr', 'safe'),
			array('id, name_en, name_de, duration, participants, no_avaliability, avaliability_from, credits_from, sort, service, no_locker, abbr', 'safe', 'on' => 'search'),
		);
	}

	/**
	 * @return array relational rules.
	 */
	public function relations()
	{
		return array(
			'trainings' => array(self::HAS_MANY, 'Training', 'type_id'),
			'avFrom' => array(self::BELONGS_TO, 'TrainingType', 'avaliability_from'),
			'crFrom' => array(self::BELONGS_TO, 'TrainingType', 'credits_from'),
			'usedIn' => array(self::HAS_MANY, 'TrainingType', 'avaliability_from'),
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
			'name_en' => 'Title English', 
			'name_de' => 'Title German',
			'participants' => 'Number of participants', 
			'no_avaliability' => 'No avaliability required',
			'abbr' => 'Abbreviation',
		);
	}
	
	public function getLocalizableAttributes()
	{
		return array(
		);
	}
	public function defaultScope()
    {
        return array(
            'order'=>'sort',
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
		$criteria->compare('t.name_en', $this->name_en, true);
		$criteria->compare('t.name_de', $this->name_de, true);
		$criteria->compare('t.duration', $this->duration);
		$criteria->compare('t.participants', $this->participants);
		$criteria->compare('t.no_avaliability', $this->no_avaliability);
		$criteria->compare('t.avaliability_from', $this->avaliability_from);
		$criteria->compare('t.credits_from', $this->credits_from);
		$criteria->compare('t.sort', $this->sort);
		$criteria->compare('t.service', $this->service);
		$criteria->compare('t.no_locker', $this->no_locker);
		return new CActiveDataProvider($this, array(
					'pagination' => array(
						'pageSize'	 => Yii::app()->user->getState('pageSize', Yii::app()->params['defaultPageSize']),
					),
					'criteria'	 => $criteria,
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
		$obj->titleFields	 = array('name_en');
		$obj->title = 'Training Type';
		return $obj;
	}

	public function getModelDisplay()
	{
		return "$this->name_en ";
	}
	
}
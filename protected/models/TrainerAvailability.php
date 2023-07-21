<?php

/**
 * This is the model class for table "{{trainer_availability}}".
 *
 * The followings are the available columns in table '{{trainer_availability}}':
 * @property integer $id
 * @property integer $trainer_id
 * @property integer $location_id
 * @property string $date
 * @property string $from
 * @property string $to
 */
class TrainerAvailability extends ActiveRecord
{
	/**
	 * Returns the static model of the specified AR class.
	 * @param string $className active record class name.
	 * @return TrainerAvailability the static model class
	 */
	public static function model($className=__CLASS__)
	{
		return parent::model($className);
	}

	/**
	 * @return string the associated database table name
	 */
	public function tableName()
	{
		return '{{trainer_availability}}';
	}

	/**
	 * @return array validation rules for model attributes.
	 */
	public function rules()
	{
		// NOTE: you should only define rules for those attributes that
		// will receive user inputs.
		return array(
			array('trainer_id, location_id, training_type_id, date, from', 'required'),
			array('trainer_id, location_id, training_type_id', 'numerical', 'integerOnly'=>true),
			// The following rule is used by search().
			// Please remove those attributes that should not be searched.
			array('id, trainer_id, location_id, date, from, to, training_type_id', 'safe'),
			array('id, trainer_id, location_id, date, from, to, training_type_id', 'safe', 'on'=>'search'),
		);
	}

	/**
	 * @return array relational rules.
	 */
	public function relations()
	{
		return array(
			'trainer' => array(self::BELONGS_TO, 'Trainer', 'trainer_id'),
			'location' => array(self::BELONGS_TO, 'Location', 'location_id'),
			'type' => array(self::BELONGS_TO, 'TrainingType', 'training_type_id'),
		);
	}

	/**
	 * @return array customized attribute labels (name=>label)
	 */
	public function attributeLabels()
	{
		return array(
			'id' => 'ID',
			'trainer_id' => 'Trainer',
			'location_id' => 'Location',
			'date' => 'Date',
			'from' => 'From',
			'to' => 'To',
			'training_type_id' => 'Type',
		);
	}

	/**
	 * Retrieves a list of models based on the current search/filter conditions.
	 * @return CActiveDataProvider the data provider that can return the models based on the search/filter conditions.
	 */
	public function search()
	{
		// Warning: Please modify the following code to remove attributes that
		// should not be searched.

		$criteria=new CDbCriteria;

		$criteria->compare('id',$this->id);
		$criteria->compare('trainer_id',$this->trainer_id);
		$criteria->compare('location_id',$this->location_id);
		$criteria->compare('date',$this->date,true);
		$criteria->compare('from',$this->from,true);
		$criteria->compare('to',$this->to,true);

		return new CActiveDataProvider($this, array(
			'criteria'=>$criteria,
		));
	}
	
	protected function beforeSave()
	{
		$this->date = date('Y-m-d', strtotime($this->date));
		if ($this->type->participants > 1 || $this->type->no_avaliability) {
			$this->to = date('H:i:s', strtotime('+' . $this->type->duration . 'minutes', strtotime($this->from)));
		}
		return parent::beforeSave();
	}
	
	protected function afterFind()
	{
		$this->date = date('d-m-Y', strtotime($this->date));
		$this->from = date('H:i', strtotime($this->from));
		$this->to = date('H:i', strtotime($this->to));
		parent::afterFind();
	}
	
	public function getSummary()
	{
		return $this->location->name .'<br/>'
				. date('d.m.Y', strtotime($this->date)) . '<br/>'
				. date('H:i', strtotime($this->from)) . ' - ' . date('H:i', strtotime($this->to));
	}
}
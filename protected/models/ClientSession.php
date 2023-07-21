<?php

class ClientSession extends ActiveRecord
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
		return '{{client_session}}';
	}

	/**
	 * @return array validation rules for model attributes.
	 */
	public function rules()
	{
		// NOTE: you should only define rules for those attributes that
		// will receive user inputs.
		return array(
			array('client_id, trainiing_type_id', 'required'),
			array('id, client_id, trainiing_type_id', 'numerical', 'integerOnly' => true),
			array('id, client_id, trainiing_type_id, paid, attended', 'safe'),
			array('id, client_id, trainiing_type_id, paid, attended', 'safe', 'on' => 'search'),
		);
	}

	/**
	 * @return array relational rules.
	 */
	public function relations()
	{
		return array(
			'client' => array(self::BELONGS_TO, 'Client', 'client_id'),
			'training_type' => array(self::BELONGS_TO, 'TrainingType', 'trainiing_type_id'),
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
			'client_id'		=> 'Client', 
			'trainiing_type_id' => 'Training type', 
			'paid'	=> 'Sessions paid', 
			'attended' => 'Sessions attended'
		);
	}
	
	public function getLocalizableAttributes()
	{
		return array(
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
		$obj->titleFields	 = array('');
		$obj->title = 'Client Sessions';
		return $obj;
	}

	public function getModelDisplay()
	{
		return "{$this->client->getModelDisplay()} {$this->training_type->name_en} {$this->attended}/{$this->paid}";
	}
	
	protected function beforeSave()
	{
		$criteria		 = new CDbCriteria;
		$criteria->compare('client_id', $this->client_id);
		$criteria->compare('trainiing_type_id', $this->trainiing_type_id);
		if ($this->id) {
			$criteria->compare('id', '<>' . $this->id);
		}
		
		if (ClientSession::model()->count($criteria)) {
			$this->addError('trainiing_type_id', 'Client already have session defined for this training type');
			return false;
		}
		
		return true;
	}
}
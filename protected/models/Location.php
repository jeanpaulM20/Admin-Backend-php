<?php

/**
 * @property integer $id	
 * @property string $name	
 * @property string $address	
 * @property string $zip	
 * @property string $city	
 * @property string $opening_times	
 * @property string $e_mail	
 * @property string $phone	
 * @property string $foto	
 * @property string $longitude	
 * @property string $latitude	
 * @property integer $active	
 * @property integer $published	
 */
class Location extends ActiveRecord
{

	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	

	/**
	 * Returns the static model of the specified AR class.
	 * @param string $className active record class name.
	 * @return $name the static model class
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
		return '{{location}}';
	}

	/**
	 * @return array validation rules for model attributes.
	 */
	public function rules()
	{
		// NOTE: you should only define rules for those attributes that
		// will receive user inputs.
		return array(
			array('id', 'numerical', 'integerOnly'=>true),
			array('name, address, zip, city, e_mail, phone, longitude, latitude', 'length', 'max'=>255),
			array('trainers, offers, id, name, address, zip, city, opening_times, e_mail, phone, foto, longitude, latitude, active, published', 'safe'),
			array('trainers, offers, id, name, address, zip, city, opening_times, e_mail, phone, foto, longitude, latitude, active, published', 'safe', 'on' => 'search'),
		);
	}

	/**
	 * @return array relational rules.
	 */
	public function relations()
	{
		return array(
			'trainings' => array(self::HAS_MANY, 'Training', 'location_id'),
			'trainers' => array(self::MANY_MANY, 'Trainer', 'tbl_trainer_location(location_id, trainer_id)'),
			'offers' => array(self::MANY_MANY, 'Offer', 'tbl_offer_location(location_id, offer_id)'),
			
			
			
			
			
			
			
			
			
			
			
			
			
		);
	}
	
	public function behaviors()
	{
		return array(
			'activerecord-relation'=>array(
				'class'=>'ext.yiiext.behaviors.activerecord-relation.EActiveRecordRelationBehavior',
		));
	}

	/**
	 * @return array customized attribute labels (name=>label)
	 */
	public function attributeLabels()
	{
		return array(
			'id' => 'id',
			'name' => 'Name',
			'address' => 'Address',
			'zip' => 'ZIP',
			'city' => 'City',
			'opening_times' => 'Opening Times',
			'e_mail' => 'E-Mail',
			'phone' => 'Phone',
			'foto' => 'Foto',
			'longitude' => 'Longitude',
			'latitude' => 'Latitude',
			'active' => 'active',
			'published' => 'published',
		);
	}

	/**
	 * Retrieves a list of models based on the current search/filter conditions.
	 * @return CActiveDataProvider the data provider that can return the models based on the search/filter conditions.
	 */
	public function search()
	{
		$criteria=new CDbCriteria;
		$criteria->with = array();
		$criteria->compare('t.id',$this->id);
		$criteria->compare('t.name',$this->name,true);
		$criteria->compare('t.address',$this->address,true);
		$criteria->compare('t.zip',$this->zip,true);
		$criteria->compare('t.city',$this->city,true);
		$criteria->compare('t.opening_times',$this->opening_times);
		$criteria->compare('t.e_mail',$this->e_mail,true);
		$criteria->compare('t.phone',$this->phone,true);
		$criteria->compare('t.foto',$this->foto);
		$criteria->compare('t.longitude',$this->longitude,true);
		$criteria->compare('t.latitude',$this->latitude,true);
		$criteria->compare('t.active',$this->active);
		$criteria->compare('t.published',$this->published);

		return new CActiveDataProvider($this, array(
			'pagination'=>array(
				'pageSize'=> Yii::app()->user->getState('pageSize',Yii::app()->params['defaultPageSize']),
			),
			'criteria'=>$criteria,
			'sort'=>array(
				'attributes'=>array(
		
		
		
		
		
		
		
		
		
		
		
		
		
					'*',
				),
			),
		));
	}
	
	
	public static function getDropdownList($withEmpty = false) {
		$models = self::model()->findAll();
		$list = array();
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
		$obj = new stdClass();
		$obj->fields = $this->attributeLabels();
		$obj->titleFields = array('name');
		$obj->title = 'Location';
		return $obj;
	}
	
	public function getModelDisplay()
	{
		return "$this->name ";
	}
}
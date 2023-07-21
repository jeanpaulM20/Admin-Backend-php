<?php

/**
 * @property integer $id	
 * @property string $token	
 * @property string $date	
 * @property integer $sort	
 * @property integer $client_id	
 */
class Clientaccesstoken extends ActiveRecord
{

	public $date_range = array();
	public $client_search;

	public function defaultScope()
	{
		return array(
			'order' => 'sort',
		);
	}

	/**
	 * Returns the static model of the specified AR class.
	 * @param string $className active record class name.
	 * @return $name the static model class
	 */
	public static function model($className = __CLASS__)
	{
		return parent::model($className);
	}

	public static function generate($client)
	{
		$token							 = new Clientaccesstoken;
		$token->client_id				 = $client->getPrimaryKey();
		$token->token					 = md5($client->getPrimaryKey() . time());
		$token->save();
		$client->client_access_tokens[]	 = $token;
		$client->save();
		return $token;
	}

	/**
	 * @return string the associated database table name
	 */
	public function tableName()
	{
		return '{{client_access_token}}';
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
			array('id, sort, client_id', 'numerical', 'integerOnly' => true),
			array('token', 'length', 'max' => 255),
			array('id, token, date, date_range, sort, client_id, client_search', 'safe'),
			array('id, token, date, date_range, sort, client_id, client_search', 'safe', 'on' => 'search'),
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
			'token'			 => 'token',
			'date'			 => 'date',
			'date_range'	 => 'date',
			'sort'			 => 'sort',
			'client_id'		 => 'Client',
			'client_search'	 => 'Client',
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
		$criteria->compare('t.token', $this->token, true);
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
		$criteria->compare('t.sort', $this->sort);
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

	public function getModelDescription()
	{
		$obj				 = new stdClass();
		$obj->fields		 = $this->attributeLabels();
		$obj->titleFields	 = array('id');
		$obj->title = 'Client Access token';
		return $obj;
	}

	public function getModelDisplay()
	{
		return "$this->id ";
	}

}
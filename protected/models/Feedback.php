<?php

class Feedback extends ActiveRecord
{
	public $client_search;
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
		return '{{feedback}}';
	}

	/**
	 * @return array validation rules for model attributes.
	 */
	public function rules()
	{
		// NOTE: you should only define rules for those attributes that
		// will receive user inputs.
		return array(
			array('client_id, trainer_id, text, read_client, read_trainer, client_search, trainer_search, is_circle', 'safe'),
			array('client_id, trainer_id, text, read_client, read_trainer, client_search, trainer_search, is_circle', 'safe', 'on' => 'search'),
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

	public function getModelDisplay()
	{
		return "$this->text ";
	}
	
	public function search()
	{
		$criteria		 = new CDbCriteria;
		$criteria->with	 = array();
		$criteria->compare('t.id', $this->id);
		
		$criteria->compare('t.text', $this->text, true);
		
		$criteria->with[]			 = 'client';
		$client_search	 = new CDbCriteria;
		$client_search->compare('client.clientid', $this->client_search, true, 'OR');
		$client_search->compare('client.surname', $this->client_search, true, 'OR');
		$client_search->compare('client.name', $this->client_search, true, 'OR');
		$criteria->mergeWith($client_search);
		
		$criteria->with[]			 = 'trainer';
		$trainer_search = new CDbCriteria;
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
							'client_search'	 => array('asc'				 => 'client.clientid,client.surname,client.name', 'desc'				 => 'client.clientid DESC,client.surname DESC,client.name DESC',),
							'trainer_search' => array('asc'	 => 'trainer.surname,trainer.name', 'desc'	 => 'trainer.surname DESC,trainer.name DESC',),
							'*',
						),
					),
				));
	}
}
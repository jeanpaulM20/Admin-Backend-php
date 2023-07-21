<?php

/**
 * @property integer $id	
 * @property string $timestamp	
 * @property float $value	
 * @property integer $sort	
 * @property integer $review_id	
 */
class Reviewheartratetimeseries extends ActiveRecord
{

	
	
	public $timestamp_range = array();
	
	
	
	
	
	public $review_search;
	

	public function defaultScope()
    {
        return array(
            'order'=>'sort',
        );
    }
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
		return '{{review_heart_rate_timeseries}}';
	}

	/**
	 * @return array validation rules for model attributes.
	 */
	public function rules()
	{
		// NOTE: you should only define rules for those attributes that
		// will receive user inputs.
		return array(
			array('review_id', 'required'),
			array('id, sort, review_id', 'numerical', 'integerOnly'=>true),
			array('id, timestamp, timestamp_range, value, sort, review_id, review_search', 'safe'),
			array('id, timestamp, timestamp_range, value, sort, review_id, review_search', 'safe', 'on' => 'search'),
		);
	}

	/**
	 * @return array relational rules.
	 */
	public function relations()
	{
		return array(
			'review' => array(self::BELONGS_TO, 'Review', 'review_id'),
			
			
			
			
			
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
			'timestamp' => 'Timestamp',
			'timestamp_range' => 'Timestamp',
			'value' => 'Value',
			'sort' => 'sort',
			'review_id' => 'Review',
			'review_search' => 'Review',
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
		//timestamp_range
$from = $to = '';
if (count($this->timestamp_range) >= 1) {
	if (isset($this->timestamp_range['from'])) {
		$from = $this->timestamp_range['from'];
	}
	if (isset($this->timestamp_range['to'])) {
		$to = $this->timestamp_range['to'];
	}
}
if ($from != '' || $to != '') {
	if ($from != '') {
		$criteria->compare('t.timestamp', ">= $from", true);
	}
	if ($to != '') {
		$criteria->compare('t.timestamp', "< $to", true);
	}
}
		$criteria->compare('t.value',$this->value);
		$criteria->compare('t.sort',$this->sort);
		$criteria->with[] = 'review';
$review_search = new CDbCriteria;
$review_search->compare('review.file',$this->review_search,true, 'OR');
$review_search->compare('review.duration',$this->review_search,true, 'OR');
$review_search->compare('review.kcal',$this->review_search,true, 'OR');
$review_search->compare('review.heart_rate',$this->review_search,true, 'OR');
$criteria->mergeWith($review_search);

		return new CActiveDataProvider($this, array(
			'pagination'=>array(
				'pageSize'=> Yii::app()->user->getState('pageSize',Yii::app()->params['defaultPageSize']),
			),
			'criteria'=>$criteria,
			'sort'=>array(
				'attributes'=>array(
		
		
		
		
		'review_search'=>array('asc'=>'review.file,review.duration,review.kcal,review.heart_rate','desc'=>'review.file DESC,review.duration DESC,review.kcal DESC,review.heart_rate DESC',),
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
		$obj->titleFields = array('timestamp', 'value');
		$obj->title = 'Review Heart Rate Timeseries';
		return $obj;
	}
	
	public function getModelDisplay()
	{
		return "$this->timestamp $this->value";
	}
}
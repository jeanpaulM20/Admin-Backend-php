<?php

/**
 * @property integer $id	
 * @property string $timestamp	
 * @property float $value	
 * @property integer $sort	
 * @property integer $review_id	
 */
class ContentFoto extends ActiveRecord
{

	public $content_search;
	

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
		return '{{content_fotos}}';
	}

	/**
	 * @return array validation rules for model attributes.
	 */
	public function rules()
	{
		// NOTE: you should only define rules for those attributes that
		// will receive user inputs.
		return array(
			array('content_id', 'required'),
			array('id, sort, content_id', 'numerical', 'integerOnly'=>true),
			array('id, file, sort, content_id, content_search', 'safe'),
			array('id, file, sort, content_id, content_search', 'safe', 'on' => 'search'),
		);
	}

	/**
	 * @return array relational rules.
	 */
	public function relations()
	{
		return array(
			'content' => array(self::BELONGS_TO, 'Content', 'content_id'),
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
			'file' => 'File',
			'sort' => 'sort',
			'content_id' => 'Content',
			'content_search' => 'Content',
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
		
		$criteria->compare('t.file',$this->value, true);
		$criteria->compare('t.sort',$this->sort);
		$criteria->with[] = 'content';
		$content_search = new CDbCriteria;
		$content_search->compare('review.name',$this->content_search,true);
		$criteria->mergeWith($content_search);

		return new CActiveDataProvider($this, array(
			'pagination'=>array(
				'pageSize'=> Yii::app()->user->getState('pageSize',Yii::app()->params['defaultPageSize']),
			),
			'criteria'=>$criteria,
			'sort'=>array(
				'attributes'=>array(
					'content_search'=>array('asc'=>'content.name,','desc'=>'content.name DESC'),
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
		$obj->titleFields = array('file');
		$obj->title = 'Content fotos';
		return $obj;
	}
	
	public function getModelDisplay()
	{
		return "$this->file";
	}
}
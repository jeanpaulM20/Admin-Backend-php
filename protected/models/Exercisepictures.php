<?php

/**
 * @property integer $id	
 * @property string $label	
 * @property string $picture	
 * @property string $description	
 * @property integer $published	
 * @property integer $sort	
 * @property integer $exercise_id	
 */
class Exercisepictures extends ActiveRecord
{

	public $exercise_search;

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

	/**
	 * @return string the associated database table name
	 */
	public function tableName()
	{
		return '{{exercise_pictures}}';
	}

	/**
	 * @return array validation rules for model attributes.
	 */
	public function rules()
	{
		// NOTE: you should only define rules for those attributes that
		// will receive user inputs.
		return array(
			array('exercise_id', 'required'),
			array('id, sort, exercise_id, language_id', 'numerical', 'integerOnly' => true),
			array('label', 'length', 'max' => 255),
			array('id, label, picture, description, published, sort, exercise_id, exercise_search, language_id', 'safe'),
			array('id, label, picture, description, published, sort, exercise_id, exercise_search, language_id', 'safe', 'on' => 'search'),
		);
	}

	/**
	 * @return array relational rules.
	 */
	public function relations()
	{
		return array(
			'exercise' => array(self::BELONGS_TO, 'Exercise', 'exercise_id'),
			'language' => array(self::BELONGS_TO, 'Language', 'language_id'),
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
			'id'				 => 'id',
			'label'				 => 'Label',
			'picture'			 => 'Picture',
			'description'		 => 'Description',
			'published'			 => 'published',
			'sort'				 => 'sort',
			'exercise_id'		 => 'Exercise',
			'exercise_search'	 => 'Exercise',
			'language_id'		 => 'language',
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
		$criteria->compare('t.label', $this->label, true);
		$criteria->compare('t.picture', $this->picture);
		$criteria->compare('t.description', $this->description);
		$criteria->compare('t.published', $this->published);
		$criteria->compare('t.sort', $this->sort);
		$criteria->with[]	 = 'exercise';
		$exercise_search	 = new CDbCriteria;
		$exercise_search->compare('exercise.name', $this->exercise_search, true, 'OR');
		$exercise_search->compare('exercise.group', $this->exercise_search, true, 'OR');
		$exercise_search->compare('exercise.subgroup', $this->exercise_search, true, 'OR');
		$criteria->mergeWith($exercise_search);

		return new CActiveDataProvider($this, array(
					'pagination' => array(
						'pageSize'	 => Yii::app()->user->getState('pageSize', Yii::app()->params['defaultPageSize']),
					),
					'criteria'	 => $criteria,
					'sort'		 => array(
						'attributes' => array(
							'exercise_search' => array('asc'	 => 'exercise.name,exercise.group,exercise.subgroup', 'desc'	 => 'exercise.name DESC,exercise.group DESC,exercise.subgroup DESC',),
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
		$obj->titleFields	 = array('label', 'picture');
		$obj->title = 'Exercise Pictures';
		return $obj;
	}

	public function getModelDisplay()
	{
		return "$this->label $this->picture ";
	}

}
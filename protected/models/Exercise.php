<?php

/**
 * @property integer $id	
 * @property string $name	
 * @property string $group	
 * @property string $subgroup	
 * @property string $pictures	
 */
class Exercise extends ActiveRecord
{

	public $subgroup_search;
	public $group_search;

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
		return '{{exercise}}';
	}

	/**
	 * @return array validation rules for model attributes.
	 */
	public function rules()
	{
		// NOTE: you should only define rules for those attributes that
		// will receive user inputs.
		return array(
			array('id, subgroup_id, group_id', 'numerical', 'integerOnly' => true),
			array('name', 'length', 'max' => 255),
			array('exercisesets, id, name, group_id, pictures, archive, published', 'safe'),
			array('exercisesets, id, name, group_id, subgroup_search, pictures, archive, published', 'safe', 'on' => 'search'),
		);
	}

	/**
	 * @return array relational rules.
	 */
	public function relations()
	{
		return array(
			'exercise_pictures' => array(self::HAS_MANY, 'Exercisepictures', 'exercise_id'),
			'exercisesets' => array(self::MANY_MANY, 'Exerciseset', 'tbl_exerciseset_exercise(exercise_id,exerciseset_id)'),
			'group' => array(self::BELONGS_TO, 'Exercisegroup', 'group_id'),
			'subgroup' => array(self::BELONGS_TO, 'Exercisesubgroup', 'subgroup_id'),
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
			'name'				 => 'Name',
			'group_id'		 => 'Group',
			'group_search'	 => 'Group',
			'subgroup_id'		 => 'Subgroup',
			'subgroup_search'	 => 'Subgroup',
			'pictures'			 => 'Pictures',
			'archive'			 => 'Archive',
			'published'			 => 'Publiched',
		);
	}

	public function getLocalizableAttributes()
	{
		return array(
			'name'
		);
	}

	/**
	 * Retrieves a list of models based on the current search/filter conditions.
	 * @return CActiveDataProvider the data provider that can return the models based on the search/filter conditions.
	 */
	public function search()
	{
		$criteria		 = new CDbCriteria;
		$criteria->with	 = array('group', 'subgroup');
		$criteria->compare('t.id', $this->id);
		$criteria->compare('t.name', $this->name, true);
		$criteria->compare('t.group_id', $this->group_id);
		$criteria->compare('t.subgroup_id', $this->subgroup_id);


		return new CActiveDataProvider($this, array(
					'pagination' => array(
						'pageSize'	 => Yii::app()->user->getState('pageSize', Yii::app()->params['defaultPageSize']),
					),
					'criteria'	 => $criteria,
					'sort'		 => array(
						'attributes' => array(
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
		$obj->titleFields	 = array('name', 'group', 'subgroup');
		$obj->title = 'Exercise';
		return $obj;
	}

	public function getModelDisplay()
	{
		return "$this->name {$this->group->name} {$this->subgroup->name}";
	}

}
<?php

/**
 * @property integer $id	
 * @property string $name	
 * @property string $group	
 * @property string $type	
 * @property string $preview	
 * @property string $teaser	
 * @property string $file	
 * @property string $startdate	
 * @property string $enddate	
 * @property integer $archive	
 * @property integer $published	
 * @property integer $language_rel	
 * @property integer $trainer_id	
 */
class Content extends ActiveRecord {

	protected $type_values = array(
		'Sport Clinic News' => 'Sport Clinic News',
		'Knowledge' => 'Knowledge',
	);

	public function getTypeValues() {
		return $this->type_values;
	}

	public function getType() {
		if ($this->type) {
			return $this->type_values[$this->type];
		}
	}

	public $startdate_range = array();
	public $enddate_range = array();
	public $language_search;
	public $trainer_search;

	/**
	 * Returns the static model of the specified AR class.
	 * @param string $className active record class name.
	 * @return $name the static model class
	 */
	public static function model($className = __CLASS__) {
		return parent::model($className);
	}

	/**
	 * @return string the associated database table name
	 */
	public function tableName() {
		return '{{content}}';
	}

	/**
	 * @return array validation rules for model attributes.
	 */
	public function rules() {
		// NOTE: you should only define rules for those attributes that
		// will receive user inputs.
		return array(
			array('type', 'in', 'range' => array_keys($this->getTypeValues()), 'allowEmpty' => false),
			array('id, language_rel, trainer_id', 'numerical', 'integerOnly' => true),
			array('name, group', 'length', 'max' => 255),
			array('clients, id, name, group, type, preview, teaser, file, startdate, startdate_range, enddate, enddate_range, archive, published, language_rel, language_search, trainer_id, trainer_search', 'safe'),
			array('clients, id, name, group, type, preview, teaser, file, startdate, startdate_range, enddate, enddate_range, archive, published, language_rel, language_search, trainer_id, trainer_search', 'safe', 'on' => 'search'),
		);
	}

	/**
	 * @return array relational rules.
	 */
	public function relations() {
		return array(
			'trainer' => array(self::BELONGS_TO, 'Trainer', 'trainer_id'),
			'clients' => array(self::MANY_MANY, 'Client', 'tbl_content_client(content_id, client_id)'),
			'language' => array(self::BELONGS_TO, 'Language', 'language_rel'),
			'content_fotos' => array(self::HAS_MANY, 'ContentFoto', 'content_id'),
		);
	}

	public function behaviors() {
		return array(
			'activerecord-relation' => array(
				'class' => 'ext.yiiext.behaviors.activerecord-relation.EActiveRecordRelationBehavior',
		));
	}

	/**
	 * @return array customized attribute labels (name=>label)
	 */
	public function attributeLabels() {
		return array(
			'id' => 'id',
			'name' => 'Name',
			'group' => 'Group',
			'type' => 'Type',
			'preview' => 'Preview',
			'teaser' => 'Teaser',
			'file' => 'File',
			'startdate' => 'Startdate',
			'startdate_range' => 'Startdate',
			'enddate' => 'Enddate',
			'enddate_range' => 'Enddate',
			'archive' => 'archive',
			'published' => 'published',
			'language_rel' => 'Language',
			'language_search' => 'Language',
			'trainer_id' => 'Trainer',
			'trainer_search' => 'Trainer',
		);
	}

	/**
	 * Retrieves a list of models based on the current search/filter conditions.
	 * @return CActiveDataProvider the data provider that can return the models based on the search/filter conditions.
	 */
	public function search() {
		$criteria = new CDbCriteria;
		$criteria->with = array();
		$criteria->compare('t.id', $this->id);
		$criteria->compare('t.name', $this->name, true);
		$criteria->compare('t.group', $this->group, true);
		$criteria->compare('t.type', $this->type);
		$criteria->compare('t.preview', $this->preview);
		$criteria->compare('t.teaser', $this->teaser);
		$criteria->compare('t.file', $this->file);
		//startdate_range
		$from = $to = '';
		if (count($this->startdate_range) >= 1) {
			if (isset($this->startdate_range['from'])) {
				$from = $this->startdate_range['from'];
			}
			if (isset($this->startdate_range['to'])) {
				$to = $this->startdate_range['to'];
			}
		}
		if ($from != '' || $to != '') {
			if ($from != '') {
				$criteria->compare('t.startdate', ">= $from", true);
			}
			if ($to != '') {
				$criteria->compare('t.startdate', "< $to", true);
			}
		}
		//enddate_range
		$from = $to = '';
		if (count($this->enddate_range) >= 1) {
			if (isset($this->enddate_range['from'])) {
				$from = $this->enddate_range['from'];
			}
			if (isset($this->enddate_range['to'])) {
				$to = $this->enddate_range['to'];
			}
		}
		if ($from != '' || $to != '') {
			if ($from != '') {
				$criteria->compare('t.enddate', ">= $from", true);
			}
			if ($to != '') {
				$criteria->compare('t.enddate', "< $to", true);
			}
		}
		$criteria->compare('t.archive', $this->archive);
		$criteria->compare('t.published', $this->published);
		$criteria->with[] = 'language';
		$language_search = new CDbCriteria;
		$language_search->compare('language.language', $this->language_search, true, 'OR');
		$criteria->mergeWith($language_search);
		$criteria->with[] = 'trainer';
		$trainer_search = new CDbCriteria;
		$trainer_search->compare('trainer.surname', $this->trainer_search, true, 'OR');
		$trainer_search->compare('trainer.name', $this->trainer_search, true, 'OR');
		$criteria->mergeWith($trainer_search);

		return new CActiveDataProvider($this, array(
			'pagination' => array(
				'pageSize' => Yii::app()->user->getState('pageSize', Yii::app()->params['defaultPageSize']),
			),
			'criteria' => $criteria,
			'sort' => array(
				'attributes' => array(
					'language_search' => array('asc' => 'language.language', 'desc' => 'language.language DESC',),
					'trainer_search' => array('asc' => 'trainer.surname,trainer.name', 'desc' => 'trainer.surname DESC,trainer.name DESC',),
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

	public function getModelDescription() {
		$obj = new stdClass();
		$obj->fields = $this->attributeLabels();
		$obj->titleFields = array('name', 'group');
		$obj->title = 'Content';
		return $obj;
	}

	public function getModelDisplay() {
		return "$this->name $this->group ";
	}

	public function scopes() {
		return array(
			'active' => array(
				'condition' => 'active=1',
			),
		);
	}

}
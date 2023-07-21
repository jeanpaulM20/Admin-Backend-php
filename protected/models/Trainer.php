<?php

/**
 * @property integer $id
 * @property string $surname
 * @property string $name
 * @property string $e_mail
 * @property string $phone
 * @property string $mobile
 * @property string $foto
 * @property string $color
 * @property integer $active
 * @property integer $published
 */
class Trainer extends ActiveRecord {

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
		return '{{trainer}}';
	}

	/**
	 * @return array validation rules for model attributes.
	 */
	public function rules() {
		// NOTE: you should only define rules for those attributes that
		// will receive user inputs.
		return array(
			array('id', 'numerical', 'integerOnly' => true),
			array('surname, name, e_mail, phone, mobile', 'length', 'max' => 255),
			array('locations, passcode, id, surname, name, e_mail, phone, mobile, foto, color, active, published, position, qualification', 'safe'),
			array('locations, passcode, id, surname, name, e_mail, phone, mobile, foto, color, active, published, position, qualification', 'safe', 'on' => 'search'),
		);
	}

	/**
	 * @return array relational rules.
	 */
	public function relations() {
		return array(
			'contents' => array(self::HAS_MANY, 'Content', 'trainer_id'),
			'offers' => array(self::HAS_MANY, 'Offer', 'trainer_id'),
			'clients' => array(self::HAS_MANY, 'Client', 'trainer_id'),
			'trainings' => array(self::HAS_MANY, 'Training', 'trainer_id'),
			'locations' => array(self::MANY_MANY, 'Location', 'tbl_trainer_location(trainer_id, location_id)'),
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
			'surname' => 'Surname',
			'name' => 'Name',
			'e_mail' => 'E-Mail',
			'phone' => 'Phone',
			'mobile' => 'Mobile',
			'foto' => 'Foto',
			'color' => 'Color',
			'active' => 'active',
			'published' => 'published',
			'passcode' => 'Passcode',
			'position' => 'Position',
			'qualification' => 'Qualification'
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
		$criteria->compare('t.surname', $this->surname, true);
		$criteria->compare('t.name', $this->name, true);
		$criteria->compare('t.e_mail', $this->e_mail, true);
		$criteria->compare('t.phone', $this->phone, true);
		$criteria->compare('t.mobile', $this->mobile, true);
		$criteria->compare('t.position', $this->position, true);
		$criteria->compare('t.qualification', $this->qualification, true);
		$criteria->compare('t.foto', $this->foto);
		$criteria->compare('t.active', $this->active);
		$criteria->compare('t.published', $this->published);

		return new CActiveDataProvider($this, array(
			'pagination' => array(
				'pageSize' => Yii::app()->user->getState('pageSize', Yii::app()->params['defaultPageSize']),
			),
			'criteria' => $criteria,
			'sort' => array(
				'attributes' => array(
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
		$obj->titleFields = array('surname', 'name');
		$obj->title = 'Trainer';
		return $obj;
	}

	public function getModelDisplay() {
		return "$this->surname $this->name ";
	}

	public function getLocationAvailability($location_id, $from = false, $to = false) {
		$result = array();

		$condition = '';
		$params = array();
		if ($from) {
			$condition .= 't.date >= :from';
			$params['from'] = date('Y-m-d', strtotime($from));
		}

		if ($to) {
			if ($condition != '') {
				$condition .= ' and ';
			}
			$condition .= 't.date <= :to';
			$params['to'] = date('Y-m-d', strtotime($to));
		}

		$availabilities = TrainerAvailability::model()->findAllByAttributes(array(
			'trainer_id' => $this->id,
			'location_id' => $location_id
				), $condition, $params);


		foreach ($availabilities as $one) {
			if (!is_array($result[$one->date])) {
				$result[$one->date] = array();
			}
			if ($one->type->participants > 1) {
				if (count($one->type->trainings(array('condition' => 'date = :date and starttime = :from', 'params' => array('date' => $one->date, 'from' => $one->from)))) < $one->type->participants) {
					$result[$one->date][] = $one->attributes;
				}
			} else {
				$result[$one->date][] = $one->attributes;
			}
		}

		$types = Yii::app()->db->createCommand()
				->select('id, avaliability_from')
				->from('tbl_training_type')
				->where('participants = 1 or avaliability_from is not null')
				->queryAll();
		$type_ids = array();
		foreach ($types as $type) {
			$type_ids[] = $type['id'];
		}
		
		$trainings = Yii::app()->db->createCommand()
				->select('date, starttime, type_id')
				->from('tbl_training')
				->where('(status = "attended" or status = "booked") and trainer_id = :trainer and location_id = :location and type_id in (' . implode(',', $type_ids) . ')', 
					array(
						'trainer' => $this->id, 
						'location' => $location_id
					)
				);

		if ($from) {
			$trainings->where($trainings->getWhere() . ' and `date` >= :from', array('from' => date('Y-m-d', strtotime($from))));
		}

		if ($to) {
			$trainings->where($trainings->getWhere() . ' and `date` <= :to', array('to' => date('Y-m-d', strtotime($to))));
		}
		
		$durationsQuery = Yii::app()->db->createCommand()
				->select('id, duration')
				->from('tbl_training_type tt')
				->queryAll();
		$durations = array();
		foreach ($durationsQuery as $one) {
			$durations[$one['id']] = $one['duration'];
		}
		
		foreach ($trainings->queryAll() as $one) {
			
			$one['date'] = date('d-m-Y', strtotime($one['date']));
			if (isset($result[$one['date']])) {
				
				$start = strtotime($one['date'] . ' ' . $one['starttime']);
				$end = $start + ($durations[$one['type_id']] * 60);
				foreach ($result[$one['date']] as $key => $value) {
					$avStart = strtotime($value['date'] . ' ' . $value['from']);
					$avEnd = strtotime($value['date'] . ' ' . $value['to']);

					if ($start <= $avStart && $end >= $avEnd) {
						unset($result[$one['date']][$key]);
					} elseif ($start <= $avStart && $end > $avStart && $end < $avEnd) {
						$result[$one['date']][$key]['from'] = date('H:i', $end);
					} elseif ($start > $avStart && $start < $avEnd && $end >= $avEnd) {
						$result[$one['date']][$key]['to'] = date('H:i', $start);
					} elseif ($start > $avStart && $end < $avEnd) {
						$left = $result[$one['date']][$key];
						$right = $left;
						$left['to'] = date('H:i', $start);
						$right['from'] = date('H:i', $end);
						$result[$one['date']][] = $left;
						$result[$one['date']][] = $right;
						unset($result[$one['date']][$key]);
					}
				}
			}
		}

		$tmpResult = $result;
		$result = array();
		$minDuration = min($durations);
		if (!$minDuration) {
			$min = 55;
		} 
		foreach ($tmpResult as $one) {
			foreach ($one as $line) {
				if ((strtotime($line['to']) - strtotime($line['from'])) / 60 < $min)
					continue;
				$result[] = $line;
			}
		}
		return $result;
	}

	public function getAvailability($from = false, $to = false) {
		$availability = Yii::app()->db->createCommand()
				->select('id, location_id, date, from, to')
				->from('tbl_trainer_availability')
				->where('trainer_id = :trainer', array('trainer' => $this->id));

		if ($from) {
			$availability->where($availability->getWhere() . ' and date >= :from', array('from' => date('Y-m-d', strtotime($from))));
		}

		if ($to) {
			$availability->where($availability->getWhere() . ' and date <= :to', array('to' => date('Y-m-d', strtotime($to))));
		}


		return $availability->queryAll();
	}

	public function scopes() {
		return array(
			'active' => array(
				'condition' => 'active=1',
			),
		);
	}

	protected function _regenerateQRCode() {
		$this->qrcode = md5($this->id . time() . rand(1, 3000));
		$this->qrcode_valid_to = date('Y-m-d H:i:s', strtotime('+10minutes'));
		$this->save();
	}

	public function getQRCode() {
		$this->_regenerateQRCode();
		return $this->qrcode;
	}

	public function getQRCodeImage() {
		Yii::import('application.vendors.phpqrcode.qrlib', true);

		QRcode::png($this->getQRCode(), false, 'M', 6, 2);
	}

	public function getQRCodeDataUri() {


		Yii::import('application.vendors.phpqrcode.qrlib', true);

		ob_start();
		QRcode::png($this->getQRCode(), false, 'M', 6, 2);
		$result = ob_get_contents();
		ob_end_clean();

		return "data:image/png;base64," . base64_encode($result);
	}

	public function getInitials() {
		return substr($this->surname, 0, 1) . substr($this->name, 0, 1);
	}

}

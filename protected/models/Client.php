<?php

/**
 * @property integer $id
 * @property string $clientid
 * @property string $clientpasscode
 * @property string $surname
 * @property string $name
 * @property string $birthday
 * @property string $e_mail
 * @property string $phone
 * @property string $mobile
 * @property string $foto
 * @property integer $active
 * @property string $access_token
 */
class Client extends ActiveRecord
{

	public $birthday_range = array();

	protected $gender_values = array(
		'm'				 => 'Male',
		'f'			 => 'Female',
	);

	public function getGenderValues()
	{
		return $this->gender_values;
	}

	public function getGender()
	{
		if ($this->gender) {
			return $this->gender_values[$this->gender];
		}
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
		return '{{client}}';
	}

	/**
	 * @return array validation rules for model attributes.
	 */
	public function rules()
	{
		// NOTE: you should only define rules for those attributes that
		// will receive user inputs.
		return array(
			array('id', 'numerical', 'integerOnly' => true),
			array('clientid, clientpasscode, surname, name, e_mail, phone, mobile', 'length', 'max' => 255),
			array('trainers, contents, gender, id, clientid, clientpasscode, surname, name, birthday, birthday_range, e_mail, phone, mobile, foto, active, access_token, qrcode_static, door_access, min_heart_rate, max_heart_rate, zip, domicile', 'safe'),
			array('trainers, contents, gender, id, clientid, clientpasscode, surname, name, birthday, birthday_range, e_mail, phone, mobile, foto, active, access_token, qrcode_static, door_access, min_heart_rate, max_heart_rate, zip, domicile', 'safe', 'on' => 'search'),
		);
	}

	/**
	 * @return array relational rules.
	 */
	public function relations()
	{
		return array(
			'preference' => array(self::HAS_ONE, 'Preference', 'client_id'),
			'anamnese' => array(self::HAS_ONE, 'ClientAnamnese', 'client_id'),
			'account' => array(self::HAS_ONE, 'Account', 'client_id'),
			'credits' => array(self::HAS_MANY, 'ClientCredits', 'client_id'),
			'client_access_tokens' => array(self::HAS_MANY, 'Clientaccesstoken', 'client_id'),
//			'goals' => array(self::HAS_MANY, 'Goal', 'client_id'),
			'metrics' => array(self::HAS_MANY, 'Metric', 'client_id', 'order' => 'date DESC'),
			'trainings' => array(self::HAS_MANY, 'Training', 'client_id'),
			'next_trainings' => array(self::HAS_MANY, 'Training', 'client_id', 'condition' => 'status="booked"'),
			'files' => array(self::HAS_MANY, 'File', 'client_id'),
			'trainers' => array(self::MANY_MANY, 'Trainer', 'tbl_trainer_client(client_id, trainer_id)'),
			'contents' => array(self::MANY_MANY, 'Content', 'tbl_content_client(client_id, content_id)'),
			'reviews'=>array(self::HAS_MANY,'Review',array('id'=>'training_id'),'through'=>'trainings'),
			'feedbacks' => array(self::HAS_MANY, 'Feedback', 'client_id'),
			'feedback_notread_client' => array(self::STAT, 'Feedback', 'client_id', 'condition' => 'read_client=0'),
			'feedback_notread_trainer' => array(self::STAT, 'Feedback', 'client_id', 'condition' => 'read_trainer=0'),
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
			'clientid'		 => 'ClientId',
			'clientpasscode' => 'ClientPassCode',
			'surname'		 => 'Surname',
			'name'			 => 'Name',
			'birthday'		 => 'Birthday',
			'birthday_range' => 'Birthday',
			'e_mail'		 => 'E-Mail',
			'phone'			 => 'Phone',
			'mobile'		 => 'Mobile',
			'foto'			 => 'Foto',
			'active'		 => 'Active',
			'access_token'	 => 'Access token',
			'gender'		=> 'Gender',
			'credits'		=> 'Client Credits',
			'qrcode_static' => 'QR Code static',
			'min_heart_rate' => 'Min heart rate', 
			'max_heart_rate' => 'Max heart rate',
			'zip' => 'ZIP',
			'domicile' => 'Domicile',
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
		$criteria->compare('t.clientid', $this->clientid, true);
		$criteria->compare('t.clientpasscode', $this->clientpasscode, true);
		$criteria->compare('t.surname', $this->surname, true);
		$criteria->compare('t.name', $this->name, true);
		$criteria->compare('t.gender', $this->gender, true);
		$criteria->compare('t.min_heart_rate', $this->min_heart_rate);
		$criteria->compare('t.max_heart_rate', $this->max_heart_rate);
		//birthday_range
		$from	 = $to		 = '';
		if (count($this->birthday_range) >= 1) {
			if (isset($this->birthday_range['from'])) {
				$from = $this->birthday_range['from'];
			}
			if (isset($this->birthday_range['to'])) {
				$to = $this->birthday_range['to'];
			}
		}
		if ($from != '' || $to != '') {
			if ($from != '') {
				$criteria->compare('t.birthday', ">= $from", true);
			}
			if ($to != '') {
				$criteria->compare('t.birthday', "< $to", true);
			}
		}
		$criteria->compare('t.e_mail', $this->e_mail, true);
		$criteria->compare('t.zip', $this->zip, true);
		$criteria->compare('t.domicile', $this->domicile, true);
		$criteria->compare('t.phone', $this->phone, true);
		$criteria->compare('t.mobile', $this->mobile, true);
		$criteria->compare('t.foto', $this->foto);
		$criteria->compare('t.active', $this->active);
		$criteria->compare('t.qrcode_static', $this->qrcode_static);
		$criteria->compare('t.door_access', $this->door_access);

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
		$obj->titleFields	 = array('clientid', 'surname', 'name');
		$obj->title = 'Client';
		return $obj;
	}

	public function getModelDisplay()
	{
		return "$this->clientid $this->surname $this->name ";
	}

	public function getFullname()
	{
		return "$this->surname $this->name";
	}

	public function scopes()
	{
		return array(
			'active' => array(
				'condition' => 'active=1',
			),
			'door_access' => array(
				'condition' => 'door_access=1'
			),
		);
	}
	
	public function getWeight() 
	{
		if (count($this->metrics)) {
			foreach ($this->metrics as $metric) {
				if ($metric->weight) {
					return $metric->weight;
				}
			}
		} 
		return false;
	}
	
	protected function afterFind()
	{
		if ($this->getWeight()) {
			$this->max_heart_rate = ($this->gender == 'm' ? Yii::app()->cfg->getItem('max_hr_coeff_man') : Yii::app()->cfg->getItem('max_hr_coeff_woman')) - (0.5 * $this->getAge()) - (0.11 * $this->getWeight());
		} else {
			if (!$this->max_heart_rate) {
				$this->max_heart_rate = 220 - $this->getAge();
			}
		}
		if (!$this->min_heart_rate) {
			$this->min_heart_rate = 60;
		}
		parent::afterFind();
	}
	
	public function getAge()
	{
		if (!$this->birthday || $this->birthday == '0000-00-00') {
			return 0;
		}
		$birth = strtotime($this->birthday);
		return (int)date('Y') - (int)date('Y', $birth);
	}

	protected function afterSave()
	{
		parent::afterSave();
		if (!$this->clientid) {
			$pad_length = 3;
			while ("$this->id" === str_pad($this->id, $pad_length, '0', STR_PAD_LEFT)) {
				$pad_length++;
			}
			$this->clientid = str_pad($this->id, $pad_length, '0', STR_PAD_LEFT);
			$this->setIsNewRecord(false);
			$this->save();
		}
	}

	protected function _regenerateQRCode() {
		$this->qrcode = md5($this->clientid . time() . rand(1, 3000));
		$this->qrcode_valid_to = date('Y-m-d H:i:s', strtotime('+10minutes'));
		$this->save();
	}

	public function getQRCode() {
		if (!$this->qrcode || !$this->qrcode_static) {
			$this->_regenerateQRCode();
		}
		return $this->qrcode;
	}

	public function getQRCodeImage()
	{
		Yii::import('application.vendors.phpqrcode.qrlib', true);

		QRcode::png($this->getQRCode(), false, 'M', 6, 2);
	}

	public function getQRCodeDataUri()
	{
		Yii::import('application.vendors.phpqrcode.qrlib', true);

		ob_start();
        QRcode::png($this->getQRCode(), false, 'M', 6, 2);
        $result = ob_get_contents();
        ob_end_clean();

		return "data:image/png;base64," . base64_encode($result);
	}

	public function getTokenForLocker()
	{
		if (count($this->client_access_tokens) > 0) {
			return $this->client_access_tokens[0];
		}
		return Clientaccesstoken::generate($this);
	}
	
	public function getCreditTotals() {
		$result = array();
		foreach ($this->credits as $credit) {
			if ($credit->expires < date('Y-m-d')) continue;
			if ($credit->startdate && $credit->startdate > date('Y-m-d')) continue;
			if (!is_array($result[$credit->training_type_id])) {
				$result[$credit->training_type_id] = array(
					'service' => $credit->training_type->service,
					'training_type' => $credit->training_type_id,
					'value' => 0,
				);
			}
			$result[$credit->training_type_id]['value'] += ($credit->paid - $credit->attended);
		}
		$booked_trainings_query = Yii::app()->db->createCommand()
				->select('count(id) value, type_id')
				->from('tbl_training')
				->where('status="booked" and credits_charged = 0 and client_id = :client_id', array('client_id' => $this->id))
				->group('type_id');
		
		foreach ($booked_trainings_query->queryAll() as $booked) {
			if (isset($result[$booked['type_id']]) && !$result[$booked['type_id']]['service']) {
				$result[$booked['type_id']]['value'] -= $booked['value'];
			}
		}
		
		return array_merge(array(), $result);
	}
	
	public function markCredit($type_id) {
		foreach ($this->credits as $credit) {
			if ($credit->training_type->service) continue;
			if ($credit->training_type_id != $type_id) continue;
			if ($credit->expires && $credit->expires != '0000-00-00' && $credit->expires < date('Y-m-d')) continue;
			if ($credit->startdate && $credit->startdate != '0000-00-00' && $credit->startdate > date('Y-m-d')) continue;
			if ($credit->paid - $credit->attended > 0) {
				$credit->attended += 1;
				$credit->save();
				return;
			}
		}
		$type = TrainingType::model()->findByPk($type_id);
		if ($type && $type->credits_from) {
			foreach ($this->credits as $credit) {
				if ($credit->training_type->service) continue;
				if ($credit->training_type_id != $type->credits_from) continue;
				if ($credit->expires && $credit->expires != '0000-00-00' && $credit->expires < date('Y-m-d')) continue;
				if ($credit->startdate && $credit->startdate != '0000-00-00' && $credit->startdate > date('Y-m-d')) continue;
				if ($credit->paid - $credit->attended > 0) {
					$credit->attended += 1;
					$credit->save();
					return;
				}
			}
		}
	}
	
	public function getFeedbackList() {
		$result = array(
			'notread_client' => $this->feedback_notread_client,
			'notread_trainer' => $this->feedback_notread_trainer,
			'feedbacks' => array()
		);
		foreach ($this->feedbacks as $one) {
			$result['feedbacks'][] = array(
				'author' => $one->trainer ? $one->trainer->getModelDisplay() : $one->client->getModelDisplay(),
				'text' => $one->text,
				'align' => $one->trainer ? 'right' : 'left',
				'read_client' => $one->read_client,
				'read_trainer' => $one->read_trainer,
				'is_circle' => $one->is_circle
			);
		}
		
		return $result;
	}
}

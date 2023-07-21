<?php

/**
 * @property Client client
 * @property string address
 * @property string profession
 * @property integer activities
 * @property integer physical_demands
 * @property string sportarts
 * @property integer sportarts_scope
 * @property integer sportarts_intencity
 * @property integer sleep_week
 * @property integer sleep_weekend
 * @property integer relaxation_week
 * @property integer relaxation_weekend
 * @property integer training_dayoff
 * @property boolean injury
 * @property string injury_type
 * @property string injury_bodypart
 * @property boolean injury_chronic
 * @property boolean disease_heartattack
 * @property boolean disease_arterial_disorder
 * @property boolean disease_raynauld_syndrome
 * @property boolean disease_vasculitis
 * @property boolean disease_cold_sensitivity
 * @property boolean disease_sensory_disturbances
 * @property boolean disease_circulatory_disorder
 * @property boolean disease_nerve_damage
 * @property boolean disease_replantation
 * @property boolean disease_peripheral_lymphatics
 * @property boolean disease_hemoglobinemia
 * @property boolean disease_kidney_bladder
 * @property boolean disease_heart_circulatory
 * @property boolean medical_treatment
 * @property boolean taking_drugs
 * @property boolean musculoskeletal_problems
 * @property string musculoskeletal_problems_description
 * @property string comments
 * @property string goals
 */
class ClientAnamnese extends ActiveRecord
{

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
		return '{{client_anamnese}}';
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
			array('client_id, activities, physical_demands, sportarts_scope, sportarts_intencity, sleep_week, sleep_weekend, relaxation_week, relaxation_weekend, training_dayoff', 'numerical', 'integerOnly' => true),
			array('injury, injury_chronic, disease_heartattack, disease_arterial_disorder, disease_raynauld_syndrome, disease_vasculitis, disease_cold_sensitivity, disease_sensory_disturbances, disease_circulatory_disorder, disease_nerve_damage, disease_replantation, disease_peripheral_lymphatics, disease_hemoglobinemia, disease_kidney_bladder, disease_heart_circulatory, musculoskeletal_problems', 'boolean'),
			array('address, profession, activities, physical_demands, sportarts, sportarts_scope, sportarts_intencity, sleep_week, sleep_weekend, relaxation_week, relaxation_weekend, training_dayoff, injury, injury_type, injury_bodypart, injury_chronic, disease_heartattack, disease_arterial_disorder, disease_raynauld_syndrome, disease_vasculitis, disease_cold_sensitivity, disease_sensory_disturbances, disease_circulatory_disorder, disease_nerve_damage, disease_replantation, disease_peripheral_lymphatics, disease_hemoglobinemia, disease_kidney_bladder, disease_heart_circulatory, musculoskeletal_problems, musculoskeletal_problems_description, comments, medical_treatment, taking_drugs, goals', 'safe'),
			//array('client_id, trainiing_type_id, paid, attended', 'safe', 'on' => 'search'),
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
			'client_id'		=> 'Client', 
			'address' => 'Anschrift',
			'comments' => 'Bemerkungen'
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
		return new CActiveDataProvider($this, array(
					'pagination' => array(
						'pageSize'	 => Yii::app()->user->getState('pageSize', Yii::app()->params['defaultPageSize']),
					),
					'criteria'	 => $criteria,
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
		$obj->titleFields	 = array('');
		$obj->title = 'Client Anamnese';
		return $obj;
	}

	public function getModelDisplay()
	{
		return "{$this->client->getModelDisplay()} Anamnese";
	}
	
	public function getActivitiesList()
	{
		return array(
			'<b>sitzende Tätigkeiten</b> (z.B. Büro, Student...)',
			'<b>m&auml;ssige Bewegung</b> (z.B.: Handwerker, Hausmeister, Hausfrau...)',
			'<b>intensive Bewegung</b> (z.B.: Briefträger, Wald- und Bauarbeiter...) ',
		);
	}
	
	public function getPhysicalDemandsList()
	{
		return array(
			'Ich bewege mich weniger als eine halbe Stunde pro Woche.',
			'Ich komme w&auml;hrend mindestens einer halben Stunde pro Tag ein bisschen ausser Atem.',
			'Ich &uuml;be gewisse Aktivit&auml;ten w&auml;hrend der Woche aus. Der Zeitaufwand, den ich daf&uuml;r aufw&auml;nde, ist aber geringer als 2.5 Stunden pro Woche.',
			'Ich betätige mich mindestens 2.5 Stunden pro Woche körperlich, so dass ich ein bisschen ausser Atem komme. Jedoch bewege ich mich nicht regelmässig an fünf Tagen pro Woche.',
			'Ich betätige mich mindestens 3-mal pro Woche körperlich, so dass ich zum Schwitzen komme.',
		);
	}
	
	public function getSportartsIntencityList()
	{
		return array(
			'Leichte Intensität (kein erhöhtes Atmen)',
			'Moderate Intensität (leicht erhöhtes Atmen)',
			'Anstrengende Intensität (Schwitzen)',
		);
	}
	
	public function getYesNoList()
	{
		return array(
			1 => 'Ja',
			0 => 'Nein',
		);
	}
}
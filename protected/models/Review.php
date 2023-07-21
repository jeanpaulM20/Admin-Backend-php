<?php

Yii::import('application.vendors.pchart.*');

/**
 * @property integer $id	
 * @property string $file	
 * @property string $duration	
 * @property integer $kcal	
 * @property float $heart_rate	
 * @property string $heart_rate_timeseries	
 * @property integer $exerciseset_id	
 * @property integer $training_id	
 */
class Review extends ActiveRecord {

	public $exerciseset_search;
	public $training_search;
	public $zone_time;
	public $zone_percent;
	public $create_feedback = true;

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
		return '{{review}}';
	}

	/**
	 * @return array validation rules for model attributes.
	 */
	public function rules() {
		// NOTE: you should only define rules for those attributes that
		// will receive user inputs.
		return array(
			//array('training_id', 'required'),
			array('id, kcal, exerciseset_id, training_id', 'numerical', 'integerOnly' => true),
			array('id, file, duration, kcal, heart_rate, heart_rate_timeseries, exerciseset_id, exerciseset_search, training_id, training_search, training_type, type, goal, goal_metric, bonus_goal, bonus_goal, trainingplan_id, result, feedback_emoticon, feedback_client, feedback_trainer, bonus_goal_metric, speed, distance', 'safe'),
			array('id, file, duration, kcal, heart_rate, heart_rate_timeseries, exerciseset_id, exerciseset_search, training_id, training_search, training_type, type, goal, goal_metric, bonus_goal, bonus_goal, trainingplan_id, result, feedback_emoticon, feedback_client, feedback_trainer, bonus_goal_metric, speed, distance', 'safe', 'on' => 'search'),
		);
	}

	/**
	 * @return array relational rules.
	 */
	public function relations() {
		return array(
			'review_heart_rate_timeseries' => array(self::HAS_MANY, 'Reviewheartratetimeseries', 'review_id'),
			'max_heart_rate' => array(self::STAT, 'Reviewheartratetimeseries', 'review_id', 'select' => 'max(value)'),
			'min_heart_rate' => array(self::STAT, 'Reviewheartratetimeseries', 'review_id', 'select' => 'min(value)'),
			'exerciseset' => array(self::BELONGS_TO, 'Exerciseset', 'exerciseset_id'),
			'training' => array(self::BELONGS_TO, 'Training', 'training_id'),
			'trainingplan' => array(self::BELONGS_TO, 'TrainingPlan', 'trainingplan_id'),
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
			'file' => 'File',
			'duration' => 'Duration',
			'kcal' => 'kcal',
			'heart_rate' => 'Heart Rate',
			'heart_rate_timeseries' => 'Heart Rate Timeseries',
			'exerciseset_id' => 'ExerciseSet',
			'exerciseset_search' => 'ExerciseSet',
			'training_id' => 'Training',
			'training_search' => 'Training',
			'training_type' => 'Training Type',
			'type' => 'Type',
			'goal' => 'Goal',
			'goal_metric' => 'Goal metric',
			'bonus_goal' => 'Bonus goal',
			'bonus_goal_metric' => 'Bonus goal metric',
			'result' => 'Result',
			'trainingplan_id' => 'Training Plan',
			'feedback_emoticon' => 'Feedback emoticon',
			'feedback_client' => 'Client feedback',
			'feedback_trainer' => 'Trainer feedback',
		);
	}

	public static function getTrainingTypes() {
		return array(
			'cardio' => 'Cardio training',
			'endurance' => 'Endurance training',
			'strenght' => 'Strenght training',
			'speed' => 'Speed training',
			'coordination' => 'Cordination Training',
			'free' => 'Free Training',
			'running' => 'Running',
			'fitness' => 'Fitness level',
			'interval' => 'Interval Training'
		);
	}

	public function getTrainingType() {
		$values = Review::getTrainingTypes();
		return isset($values[$this->training_type]) ? $values[$this->training_type] : '';
	}

	public static function getTypes() {
		return array(
			'maximum' => 'Maximum',
			'hard' => 'Hard',
			'moderate' => 'Moderate',
			'light' => 'Light',
			'very_light' => 'Very Light',
		);
	}

	public function getType() {
		$values = Review::getTypes();
		return isset($values[$this->type]) ? $values[$this->type] : '';
	}

	public static function getMetrics() {
		return array(
			'meter' => 'Meter',
			'cal' => 'Cal',
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
		$criteria->compare('t.file', $this->file);
		$criteria->compare('t.duration', $this->duration);
		$criteria->compare('t.kcal', $this->kcal);
		$criteria->compare('t.heart_rate', $this->heart_rate);

		$criteria->compare('t.training_type', $this->training_type);
		$criteria->compare('t.type', $this->type);
		$criteria->compare('t.goal', $this->goal);
		$criteria->compare('t.bonus_goal', $this->bonus_goal);
		$criteria->compare('t.result', $this->result);

		$criteria->compare('t.feedback_emoticon', $this->feedback_emoticon);
		$criteria->compare('t.feedback_client', $this->feedback_client, true);
		$criteria->compare('t.feedback_trainer', $this->feedback_trainer, true);

		$criteria->compare('t.speed', $this->speed);
		$criteria->compare('t.distance', $this->distance);

		$criteria->with[] = 'exerciseset';
		$exerciseset_search = new CDbCriteria;
		$exerciseset_search->compare('exerciseset.name', $this->exerciseset_search, true, 'OR');
		$criteria->mergeWith($exerciseset_search);
		$criteria->with[] = 'training';
		$training_search = new CDbCriteria;
		$training_search->compare('training.date', $this->training_search, true, 'OR');
		$training_search->compare('training.starttime', $this->training_search, true, 'OR');
		//$training_search->compare('training.endtime', $this->training_search, true, 'OR');
		$criteria->mergeWith($training_search);

		return new CActiveDataProvider($this, array(
			'pagination' => array(
				'pageSize' => Yii::app()->user->getState('pageSize', Yii::app()->params['defaultPageSize']),
			),
			'criteria' => $criteria,
			'sort' => array(
				'attributes' => array(
					'exerciseset_search' => array('asc' => 'exerciseset.name', 'desc' => 'exerciseset.name DESC',),
					'training_search' => array('asc' => 'training.date,training.starttime', 'desc' => 'training.date DESC,training.starttime DESC',),
					'*',
				),
			),
		));
	}

	public function searchOffsite() {

		$criteria = new CDbCriteria;
		$criteria->with = array();

		$criteria->compare('t.id', $this->id);
		$criteria->compare('t.file', $this->file);
		$criteria->compare('t.duration', $this->duration);
		$criteria->compare('t.kcal', $this->kcal);
		$criteria->compare('t.heart_rate', $this->heart_rate);

		$criteria->compare('t.training_type', $this->training_type);
		$criteria->compare('t.type', $this->type);
		$criteria->compare('t.goal', $this->goal);
		$criteria->compare('t.bonus_goal', $this->bonus_goal);
		$criteria->compare('t.result', $this->result);

		$criteria->compare('t.feedback_emoticon', $this->feedback_emoticon);
		$criteria->compare('t.feedback_client', $this->feedback_client, true);
		$criteria->compare('t.feedback_trainer', $this->feedback_trainer, true);

		$criteria->with[] = 'exerciseset';
		$exerciseset_search = new CDbCriteria;
		$exerciseset_search->compare('exerciseset.name', $this->exerciseset_search, true, 'OR');
		$criteria->mergeWith($exerciseset_search);
		$criteria->with[] = 'training';
		$training_search = new CDbCriteria;
		$training_search->compare('training.date', $this->training_search, true, 'OR');
		$training_search->compare('training.starttime', $this->training_search, true, 'OR');
		//$training_search->compare('training.endtime', $this->training_search, true, 'OR');
		$criteria->mergeWith($training_search);

		$criteria->compare('t.training_type', array('running', 'fitness', 'interval'));
		$criteria->order = 'training.date DESC, training.starttime DESC';

		return new CActiveDataProvider($this, array(
			'pagination' => array(
				'pageSize' => Yii::app()->user->getState('pageSize', Yii::app()->params['defaultPageSize']),
			),
			'criteria' => $criteria,
			'sort' => array(
				'attributes' => array(
					'exerciseset_search' => array('asc' => 'exerciseset.name', 'desc' => 'exerciseset.name DESC',),
					'training_search' => array('asc' => 'training.date,training.starttime,training.endtime', 'desc' => 'training.date DESC,training.starttime DESC,training.endtime DESC',),
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
		$obj->titleFields = array('file', 'duration', 'kcal', 'heart_rate');
		$obj->title = 'Review';
		return $obj;
	}

	public function getModelDisplay() {
		return date('H:i', strtotime($this->training->starttime)) . ' ' . date('d.m.Y', strtotime($this->training->date));
	}

	public function getKey() {
		switch ($this->training_type) {
			case 'running':
				return 'R';
			case 'fitness':
				return 'FL';
			case 'interval':
				return 'IT';
		}
		return 'PT';
	}

	public function parseTimeSeriesFile() {
		$fileContent = Yii::app()->CURL->run($this->file);
		$lines = array_slice(explode("\n", $fileContent), 3);
		foreach ($this->review_heart_rate_timeseries as $timeseries) {
			$timeseries->delete();
		}
		$sort = 0;
		foreach ($lines as $line) {
			$content = explode("\t", $line);
			if ($content[0] && $content[1]) {
				$t = new Reviewheartratetimeseries;
				$t->timestamp = $content[0];
				$t->value = $content[1];
				$t->review_id = $this->id;
				$t->sort = $sort;
				$t->save();
				$sort++;
			}
		}
		$this->generateChart();
	}

	public function generateChart() {
		Yii::import('application.vendors.jpgraph.jpgraph', true);
		Yii::import('application.vendors.jpgraph.jpgraph_line', true);
		Yii::import('application.vendors.jpgraph.jpgraph_plotline', true);
		Yii::import('application.vendors.jpgraph.jpgraph_date', true);

		$data = Yii::app()->db->createCommand()
				->select('timestamp, value')
				->from('tbl_review_heart_rate_timeseries')
				->where('review_id = :id', array('id' => $this->id))
				->order('timestamp')
				->queryAll();

		$this->_doGenerateGraph($data);
		$this->_doGenerateGraph($data, 'de');
	}

	protected function _getTimeInZone($zone) {

		$rates = $this->training ? array('min' => $this->training->client->min_heart_rate, 'max' => $this->training->client->max_heart_rate) : array('max' => $this->min_heart_rate, 'min' => $this->min_heart_rate);
		$step = intval(($rates['max'] - $rates['min']) * 0.25);

		switch ($zone) {
			case 'maximum':
				$bottom = $rates['max'];
			case 'hard':
				$bottom = $rates['max'] - $step;
				break;
			case 'moderate':
				$bottom = $rates['max'] - $step * 2;
				break;
			case 'light':
				$bottom = $rates['max'] - $step * 3;
				break;
			case 'very_light':
				$bottom = $rates['max'] - $step * 4;
				break;
			default:
				$bottom = $rates['max'] - $step * 4;
				break;
		}

		$data = Yii::app()->db->createCommand()
				->select('count(value) as time')
				->from('tbl_review_heart_rate_timeseries')
				->where('review_id = :id and value >= :bottom', array(
					'id' => $this->id,
					'bottom' => $bottom,
						)
				)
				->queryRow();

		return $data ? $data['time'] : 0;
	}

	protected function _doGenerateGraph($data, $lang = 'en') {
		$graph = new Graph(1024, 580);
		$graph->SetMargin(50, 20, 10, 30);
		$graph->SetMarginColor('#ffffff@1.0');
		$graph->SetColor('#ffffff@1.0');
		$graph->img->SetTransparent('#000000');

		$xdata = array();
		$ydata = array();
		$maximum = null;
		$minimum = null;

		foreach ($data as $one) {
			if (!$one['value'])
				continue;

			if ($one['value'] > $maximum) {
				$maximum = $one['value'];
			}
			if (is_null($minimum)) {
				$minimum = $one['value'];
			} elseif ($one['value'] < $minimum) {
				$minimum = $one['value'];
			}
		}

		foreach ($data as $i => $one) {
			if (!$one['value'])
				continue;

			$xdata[] = strtotime($one['timestamp']);
			$ydata[] = $one['value'];
		}

		$topbound = ((int) ($maximum / 10) + 4) * 10;
		//$bottombound = $minimum - 40 > 0 ? ((int)($minimum/10)  - 4)*10 : 0;
		$bottombound = 40;

		$graph->SetScale('datlin', $bottombound, $topbound);
		$graph->img->SetAntiAliasing(false);
		$graph->SetBox(true, array(255, 255, 255));
		$graph->SetGridDepth(DEPTH_BACK);

		$graph->xgrid->SetColor('white');
		$graph->xgrid->SetFill(false);
		$graph->xgrid->SetLineStyle('dotted');
		$graph->xgrid->SetShowEvery(6);
		$graph->xgrid->Show();

		$graph->ygrid->Show();
		$graph->ygrid->SetColor('white');
		$graph->ygrid->SetFill(false);
		$graph->ygrid->SetShowEvery(2);
		$graph->ygrid->SetLineStyle('dotted');

		$p = new LinePlot($ydata, $xdata);
		$p->SetFillGradient('#d1c321@0.9', '#000000@0.9');
		$graph->Add($p);
		$p->SetColor('#d1c321');
		$p->SetWeight(2);

		$graph->xaxis->SetColor('white');
		$graph->xaxis->SetFont(FF_DEFAULT, FS_NORMAL, 20);
		$graph->xaxis->SetTextLabelInterval(6);
		$graph->xaxis->SetLineStyle('dotted');
		$graph->xaxis->SetTickSide(SIDE_UP);
		$graph->xaxis->scale->ticks->SupressTickMarks(false);

		$graph->yaxis->SetColor('white');
		$graph->yaxis->SetFont(FF_DEFAULT, FS_NORMAL, 20);
		$graph->yaxis->SetTextLabelInterval(2);
		$graph->yaxis->SetLineStyle('dotted');
		$graph->yaxis->scale->ticks->Set(10);
		$graph->yaxis->scale->ticks->SupressTickMarks(false);
		$graph->yaxis->SetTickSide(SIDE_UP);

		$graph->InitScaleConstants();

		$rates = $this->training ? array('min' => $this->training->client->min_heart_rate, 'max' => $this->training->client->max_heart_rate) : array('max' => 0, 'min' => 0);
		if (!$rates['max']) {
			$rates['max'] = $maximum;
		}

		if (!$rates['min']) {
			$rates['min'] = (int) $maximum / 2;
		}

		$step = intval(($rates['max'] - $rates['min']) * 0.25);

		if ($rates['max'] < $topbound && $rates['max'] > $bottombound) {
			$maximumText = new Text($lang == 'de' ? 'Maximal' : 'Maximum');
			$maximumText->SetPos(55, abs($graph->yaxis->scale->Translate($rates['max'])) - 28);
			$graph->AddText($maximumText);
			$maximumText->SetColor('#c2234d');
			$maximumText->SetFont(FF_DEFAULT, FS_BOLD, 24);

			$p1 = new PlotLine();
			$p1->SetColor('#c2234d');
			$p1->SetPosition($rates['max']);
			$graph->AddLine($p1);
			$p1->SetLineStyle('solid');
		}

		if ($rates['max'] - $step < $topbound && $rates['max'] - $step > $bottombound) {
			$text = new Text($lang == 'de' ? 'Intensiv' : 'Hard');
			$text->SetPos(55, abs($graph->yaxis->scale->Translate($rates['max'] - $step)) - 28);
			$graph->AddText($text);
			$text->SetColor('#d18b37');
			$text->SetFont(FF_DEFAULT, FS_BOLD, 24);

			$line = new PlotLine();
			$line->SetColor('#d18b37');
			$line->SetPosition($rates['max'] - $step);
			$graph->AddLine($line);
		}

		if ($rates['max'] - $step * 2 < $topbound && $rates['max'] - $step * 2 > $bottombound) {
			$text = new Text($lang == 'de' ? 'Moderat' : 'Moderate');
			$text->SetPos(55, abs($graph->yaxis->scale->Translate($rates['max'] - $step * 2)) - 28);
			$graph->AddText($text);
			$text->SetColor('#839c4d');
			$text->SetFont(FF_DEFAULT, FS_BOLD, 24);

			$line = new PlotLine();
			$line->SetColor('#839c4d');
			$line->SetPosition($rates['max'] - $step * 2);
			$graph->AddLine($line);
		}

		if ($rates['max'] - $step * 3 < $topbound && $rates['max'] - $step * 3 > $bottombound) {
			$text = new Text($lang == 'de' ? 'Leicht' : 'Light');
			$text->SetPos(55, abs($graph->yaxis->scale->Translate($rates['max'] - $step * 3)) - 28);
			$graph->AddText($text);
			$text->SetColor('#03a4b6');
			$text->SetFont(FF_DEFAULT, FS_BOLD, 24);

			$line = new PlotLine();
			$line->SetColor('#03a4b6');
			$line->SetPosition($rates['max'] - $step * 3);
			$graph->AddLine($line);
		}

		if ($rates['max'] - $step * 4 < $topbound && $rates['max'] - $step * 4 > $bottombound) {
			$text = new Text($lang == 'de' ? 'Sehr Leicht' : 'Very Light');
			$text->SetPos(55, abs($graph->yaxis->scale->Translate($rates['max'] - $step * 4)) - 28);
			$graph->AddText($text);
			$text->SetColor('#9e9e9e');
			$text->SetFont(FF_DEFAULT, FS_BOLD, 24);

			$line = new PlotLine();
			$line->SetColor('#9e9e9e');
			$line->SetPosition($rates['max'] - $step * 4);
			$graph->AddLine($line);
		}

		if ($lang == 'de') {
			$graph->Stroke(Yii::getPathOfAlias('webroot') . '/media/chart/review/' . $this->id . '_de.png');
		} else {
			$graph->Stroke(Yii::getPathOfAlias('webroot') . '/media/chart/review/' . $this->id . '.png');
			$graph->Stroke(Yii::getPathOfAlias('webroot') . '/media/chart/review/' . $this->id . '_en.png');
		}
	}

	protected function afterFind() {
		if ($this->type && $this->duration && strtotime($this->duration) - strtotime('00:00:00') > 0) {
			$this->zone_time = $this->_getTimeInZone($this->type);
			if ($this->training_type == 'fitness') {
				if ($this->heart_rate > 80) {
					$this->zone_percent = 0;
				} else if ($this->heart_rate < 50) {
					$this->zone_percent = 100;
				} else {
					$this->zone_percent = round((80 - $this->heart_rate) * 100 / 30);
				}
			} else {
				$this->zone_percent = round($this->zone_time * 100 / (strtotime($this->duration) - strtotime('00:00:00')));
			}
		}
		parent::afterFind();
	}

	protected function afterSave() {
		if ($this->isNewRecord && $this->create_feedback) {
			$this->createFeedbackCircle();
		}
		parent::afterSave();
	}

	public function createFeedbackCircle() {
		$feedback = new Feedback();
		$feedback->client_id = $this->training->client_id;
		if ($this->training_type == 'fitness') {
			if ($this->heart_rate > 80) {
				$feedback->text = 0;
			} else if ($this->heart_rate < 50) {
				$feedback->text = 100;
			} else {
				$feedback->text = round((80 - $this->heart_rate) * 100 / 30);
			}
		} else {
			$feedback->text = round($this->_getTimeInZone($this->type) * 100 / (strtotime($this->duration) - strtotime('00:00:00')));
		}

		$feedback->read_client = 1;
		$feedback->read_trainer = 1;
		$feedback->is_circle = 1;
		$feedback->save();
	}

	public function getMediane() {
		switch ($this->training_type) {
			case 'maximum':
				return 0.975;
			case 'hard':
				return 0.875;
			case 'moderate':
				return 0.725;
			case 'light':
				return 0.575;
		}
		return 1;
	}

}
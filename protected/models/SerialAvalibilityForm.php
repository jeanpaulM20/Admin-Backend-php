<?php

class SerialAvalibilityForm extends CFormModel {
	
	public $trainer_id;
	public $location_id;
	public $training_type_id;
	public $from;
	public $to;
	
	public $reccurence = 'weekly';
	
	public $everyWeek = 1;
	public $everyMonth = 1;
	
	public $rMonday;
	public $rTuesday;
	public $rWednesday;
	public $rThursday;
	public $rFriday;
	public $rSatturday;
	public $rSunday;
	
	public $rDay = 1;
	
	public $rRange = 'after';
	public $rStart;
	public $rEnd;
	public $rEndAfter = 1;
	
	public function rules()
	{
		return array(
			array('location_id, training_type_id, from, to, rStart', 'required'),
			array('rMonday', 'oneDaySelected'),
			array('everyMonth', 'everyMonth'),
			array('everyWeek', 'everyWeek'),
			array('rDay', 'rDay'),
			array('rEndAfter', 'rEndAfter'),
			array('rEnd', 'rEnd'),
			array('trainer_id, location_id, training_type_id, from, to, reccurence, everyWeek, everyMonth, rMonday, rTuesday, rWednesday, rThursday, rFriday, rSatturday, rSunday, rDay, rRange, rStart, rEnd, rEndAfter', 'safe')
		);
	}
	
	public function getReccurenceList() {
		return array(
			'weekly' => 'Weekly',
			'monthly' => 'Monthly',
		);
	}
	
	public function attributeLabels()
	{
		return array(
			'location_id' => 'Location',
			'training_type_id' => 'Training type',
			'rMonday' => 'Monday',
			'rTuesday' => 'Tuesday',
			'rWednesday' => 'Wednesday',
			'rThursday' => 'Thursday',
			'rFriday' => 'Friday',
			'rSatturday' => 'Satturday',
			'rSunday' => 'Sunday',
			'rStart' => 'Reccurence start'
		);
	}
	
	public function create() {
		switch ($this->reccurence) {
			case 'weekly':
				$this->createWeekly();
				break;
			case 'monthly':
				$this->createMonthly();
				break;
		}
	}
	
	public function createWeekly() {
		$current = strtotime($this->rStart);
		$every = $this->everyWeek;
		switch ($this->rRange) {
			case 'end':
				$end = strtotime($this->rEnd);
				while(true) {
					if ($this->checkWeekday(date('N', $current))) {
						if ($every > 1) {
							$every--;
						} else {
							$avalibility = $this->buildAvalibility();
							$avalibility->date = date('Y-m-d', $current);
							$avalibility->save();
							$every = $this->everyWeek;
						}
					}
					if ($end < $current) break;
					$current = strtotime('+1day', $current);
				}
				break;
			case 'after':
				$limit = $this->rEndAfter;
				while ($limit > 0) {
					if ($this->checkWeekday(date('N', $current))) {
						if ($every > 1) {
							$every--;
						} else {
							$avalibility = $this->buildAvalibility();
							$avalibility->date = date('Y-m-d', $current);
							$avalibility->save();
							$limit--;
							$every = $this->everyWeek;
						}
					}
					$current = strtotime('+1day', $current);
				}
				break;
		}
	}
	
	public function checkWeekday($day) {
		switch ($day) {
			case '1':
				return $this->rMonday;
			case '2':
				return $this->rTuesday;
			case '3':	
				return $this->rWednesday;
			case '4':
				return $this->rThursday;
			case '5':
				return $this->rFriday;
			case '6':
				return $this->rSatturday;
			case '7':	
				return $this->rSunday;
			default:
				return false;
		}
	}
	
	public function createMonthly() {
		$start = strtotime($this->rStart);
		$month = date('m', $start);
		$year = date('Y', $start);
		
		switch ($this->rRange) {
			case 'end':
				$end = strtotime($this->rEnd);
				$endMonth = date('m', $end);
				$endYear = date('Y', $end);
				while (true) {
					$avalibility = $this->buildAvalibility();
					$avalibility->date = date('Y-m-d', mktime(0, 0, 0, $month, $this->rDay, $year));
					$avalibility->save();
					$month += $this->everyMonth;
					while ($month > 12) {
						$month -= 12;
						$year++;
					}
					if ($year == $endYear && $month > $endMonth) {
						break;
					}
				}
				break;
			case 'after':
				$limit = $this->rEndAfter;
				while ($limit > 0) {
					$avalibility = $this->buildAvalibility();
					$avalibility->date = date('Y-m-d', mktime(0, 0, 0, $month, $this->rDay, $year));
					$avalibility->save();
					$month += $this->everyMonth;
					while ($month > 12) {
						$month -= 12;
						$year++;
					}
					$limit--;
				}
				break;
		}
		
	}
	
	public function buildAvalibility() {
		$avalibility = new TrainerAvailability();
		$avalibility->from = $this->from;
		$avalibility->to = $this->to;
		$avalibility->trainer_id = $this->trainer_id;
		$avalibility->location_id = $this->location_id;
		$avalibility->training_type_id = $this->training_type_id;
		return $avalibility;
	}
	
	public function oneDaySelected($attribute,$params)
	{
		if ($this->reccurence == 'weekly') {
			if (!$this->rMonday 
					&& !$this->rTuesday
					&& !$this->rWednesday
					&& !$this->rThursday
					&& !$this->rFriday
					&& !$this->rSatturday
					&& !$this->rSunday) {
				$this->addError('reccurence','At least one weekday should be selected');
			}
		}	
	}
	
	public function everyWeek($attribute,$params) {
		if ($this->reccurence == 'weekly' && !$this->everyWeek) {
			$this->addError('everyWeek','Every field cannot be blank');
		}
	}
	
	public function everyMonth($attribute,$params) {
		if ($this->reccurence == 'monthly' && !$this->everyMonth) {
			$this->addError('everyMonth','Every field cannot be blank');
		}
	}
	
	public function rDay($attribute,$params) {
		if ($this->reccurence == 'monthly' && !$this->rDay) {
			$this->addError('rDay','Month day should be defined');
		} elseif ($this->reccurence == 'monthly' && $this->rDay < 1 || $this->rDay > 31) {
			$this->addError('rDay','Please provide valid month day');
		}
	}
	
	public function rEndAfter($attribute,$params) {
		if ($this->rRange == 'after' && !$this->rEndAfter) {
			$this->addError('rEndAfter','Number of occurances should be defined');
		}
	}
	
	public function rEnd($attribute,$params) {
		if ($this->rRange == 'end' && !$this->rEnd) {
			$this->addError('rEnd','End date should be defined');
		}
	}
}
?>

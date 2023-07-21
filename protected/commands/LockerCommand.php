<?php

class LockerCommand extends CConsoleCommand
{
    public function actionReserve() {
		Yii::log('Started reservation cron');
		
		$start = strtotime('+21minutes');
		$appointments = Training::model()->findAll('status="booked" and date = :date and (starttime < :start)',array(
			'date' => date('Y-m-d'),
			'start' => date('H:i:s', $start)
		));
		foreach ($appointments as $appointement) {
			if ($appointement->type->no_locker) continue;
			$locker = Locker::model()->findByAttributes(array('training_id' => $appointement->id));
			if ($locker) {
				if ($locker->status == 'free' && $appointement->starttime < date('H:i:s', strtotime('-20minutes'))) {
					$locker->release();
				}
				continue;
			}
			if ($appointement->starttime < date('H:i:s', strtotime('-20minutes'))) {
				continue;
			}
			
			$criteria = new CDbCriteria;
			$criteria->addCondition('t.client_id is not null');
			$criteria->compare('type', $appointement->client->gender);
			$criteria->order = 'training.starttime DESC';
			$lastlocker = Locker::model()->with('training')->find($criteria);
			if ($lastlocker) {
				$lasid = filter_var($lastlocker->locker_id, FILTER_SANITIZE_NUMBER_INT);
			} else {
				$lasid = false;
			}
			for ($i = 0; $i < 10; ++$i) {			
				if ($appointement->client->gender == 'f') {
					$nextId = $lasid ? $lasid + 4 : 10;
					if ($nextId > 18) {
						$nextId -= 9;
					}
				} else {
					$nextId = $lasid ? $lasid + 4 : 1;
					if ($nextId > 9) {
						$nextId -= 9;
					}
				}
				$loc = Locker::model()->findByAttributes(array('locker_id' => $nextId));
				if (($loc->status == 'free' || $loc->status == 'open') && !$loc->client_id) {
					$loc->reserve($appointement);
					break;
				} else {
					$lasid = $nextId;
				}
			}
		}
		
		// updating training status
		$appointments = Training::model()->findAll('status="booked" and (date < :date OR (date = :date and (starttime < :end)))',array(
			'date' => date('Y-m-d'),
			'end' => date('H:i:s')
		));
		foreach ($appointments as $appointment) {
			if ($appointement->date == date('Y-m-d')) {
				if (time() < strtotime('+' . $appointement->duration . 'minutes', strtotime($appointement->date . ' ' . $appointement->starttime))) {
					continue;
				}
			}
			Yii::log('marking as attended '.$appointment->id.", date:  ".$appointment->date." ". $appointment->starttime);
			$appointment->status = 'attended';
			$appointment->save();
		}
		
		// deducting credits
/*
		$appointments = Training::model()->findAll('credits_charged = 0 and status="booked" and (date > :date OR (date = :date and (starttime > :end)))',array(
			'date' => date('Y-m-d'),
			'end' => date('H:i:s')
		));
*/
		$appointments = Training::model()->findAll('credits_charged = 0 and (status="booked" OR status="attended") and date < :date ',array(
		    'date' => date('Y-m-d',strtotime('+48hours'))
		));
		
		foreach ($appointments as $appointment) {
			if (strtotime($appointment->date . ' ' . $appointment->starttime) < strtotime('+12hours')) {
				Yii::log('billing '.$appointment->id.", date:  ".$appointment->date." ". $appointment->starttime);
				$appointment->client->markCredit($appointment->type_id);
				$appointment->credits_charged = 1;
				$appointment->save();
			} else {
//				Yii::log('skipping(it is early) '.$appointment->id.", date:  ".$appointment->date." ". $appointment->starttime);
			}
		}
		
		$review = Review::model()->findByAttributes(array('regenerate_chart' => 1));
		if ($review) {
			$review->regenerate_chart = 0;
			!$review->save();
			$review->generateChart();
		}
		Yii::log('Finished reservation cron');
	}
}
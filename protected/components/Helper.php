<?php

class Helper 
{
	public static function getModel($name) {
		switch ($name) {
			case 'trainer':
				return Trainer::model();
			case 'trainer_avaliability':
				return TrainerAvailability::model();
			case 'client':
				return Client::model();
			case 'client_access_token':
				return Clientaccesstoken::model();
			case 'account':
				return Account::model();
			case 'location':
				return Location::model();
//			case 'goal':
//				return Goal::model();
			case 'metric':
				return Metric::model();
			case 'training':
				return Training::model();
			case 'exerciseset':
				return Exerciseset::model();
			case 'review':
				return Review::model();
			case 'review_heart_rate_timeseries':
				return Reviewheartratetimeseries::model();
			case 'exercise':
				return Exercise::model();
			case 'exercise_pictures':
				return Exercisepictures::model();
			case 'content':
				return Content::model();
			case 'offer':
				return Offer::model();
			case 'preference':
				return Preference::model();
			case 'language':
				return Language::model();
			case 'file':
				return File::model();
			case 'translation':
				return Translation::model();
			case 'exercisegroup':
				return Exercisegroup::model();
			case 'exercisesubgroup':
				return Exercisesubgroup::model();
			case 'trainingplan':
				return TrainingPlan::model();
			case 'performance_test':
				return PerformanceTest::model();
			case 'client_credits':
				return ClientCredits::model();
			case 'training_type':
				return TrainingType::model();
			case 'anamnese':
				return ClientAnamnese::model();
		}
	}
	
	public static function getModelsArray() {
		return array(
			'trainer' => 'Trainer',
			'trainingplan' => 'Trainingplan',
			'client' => 'Client',
			'client_access_token' => 'Client Access token',
			'account' => 'Account',
			'location' => 'Location',
//			'goal' => 'Goal',
			'metric' => 'Metric',
			'training' => 'Training',
			'exerciseset' => 'ExerciseSet',
			'review' => 'Review',
			'review_heart_rate_timeseries' => 'Review Heart Rate Timeseries',
			'exercise' => 'Exercise',
			'exercisegroup' => 'Exercise Group',
			'exercisesubgroup' => 'Exercise Subgroup',
			'exercise_pictures' => 'Exercise Pictures',
			'content' => 'Content',
			'offer' => 'Offer',
			'preference' => 'Preference',
			'language' => 'Language',
			'file' => 'File',
			'translation' => 'Translation',
			'performance_test' => 'Performance Test',
			'training_type' => 'Training Type',
			'client_credits' => 'Client Credits',
			'anamnese' => 'Client Anamnese',
		);
	}
	
	public static function formatDuration($duration) {
		$result = '';
		if ($duration > 60*24*7) {
			$result .= floor($duration / (60*24*7)) .'w ';
			$duration = $duration % (60*24*7);
		}
		
		if ($duration > 60*24) {
			$result .= floor($duration / (60*24)) .'d ';
			$duration = $duration % (60*24);
		}
		
		if ($duration > 60) {
			$result .= floor($duration / 60) .'h ';
			$duration = $duration % 60;
		}
		
		if ($duration > 0) {
			$result .= $duration  .'m ';
		}
		
		return trim($result) ? trim($result) : 0;
	}
	
	public static function parseDuration($duration) {
		$result = 0;
		$list = explode(' ', $duration);
		foreach ($list as $one) {
			$suffix = substr($one, -1);
			$d = (int)substr($one, 0, strlen($one) - 1);
			switch ($suffix) {
				case 'w':
					$result += $d * 60*24*7;
					break;
				case 'd':
					$result += $d * 60*24;
					break;
				case 'h':
					$result += $d * 60;
					break;
				case 'm':
					$result += $d;
					break;
			}
				
		}
		return $result ? $result : null;
	}
}
?>

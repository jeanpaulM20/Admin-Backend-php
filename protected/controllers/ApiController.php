<?php
Yii::import("application.models.api.*");
Yii::import('application.extensions.ical.iCalcreator', true);
class ApiController extends Controller
{
	/**
	 * Default response format
	 * either 'json' or 'xml'
	 */
	private $format = 'json';
	public $current_client;
	public $current_trainer;
	
	protected $_models = array(
		'trainer',
		'trainer_avaliability',
		'client',
		'client_access_token',
		'account',
		'location',
//		'goal',
		'metric',
		'training',
		'exerciseset',
		'review',
		'review_heart_rate_timeseries',
		'exercise',
		'exercise_pictures',
		'content',
		'offer',
		'preference',
		'language',
		'file',
		'translation',
		'trainingplan',
		'performance_test',
		'client_credits',
		'training_type',
		'anamnese'
	);
	
	protected $_restrictedAttributes =  array(
		'passcode',
		'qrcode',
		'qrcode_static',
		'qrcode_valid_to',
		'door_access',
		'clientpasscode',
		'id',
	);
	
	protected $_restrictedAttributesView =  array(
		'passcode',
		'qrcode',
		'qrcode_static',
		'qrcode_valid_to',
		'door_access',
		'clientpasscode',
	);
	

	/**
	 * @return array action filters
	 */
	public function filters()
	{
		return array(
			array(
				'ApiAccessFilter',
				'restricted_urls' => array(
					'api/preference',
					'api/avaliability',
					'api/fullAvaliability',
					'api/cancelTraining', 
					'api/cancelTrainingTrainer', 
					'api/inviteTraining',
					'api/inviteTrainingTrainer',
					'api/nextTrainerAppointment',
					'api/sendFile', 
					'api/sendPlan',
					'api/sendAnamnese',
					'api/clientQR',
					'api/trainerQR',
					'api/client',
					'api/training/',
					'api/metric',
					'api/performance_test',
					'api/file',
					'api/review',
					'api/anamnese',
					'api/trainingplan',
					'api/credits',
					'api/totalCredits',
					'api/saveSerialAvalibility',
					'api/saveIntervalSettings',
					'api/saveRatesAndBelt',
					'api/changePassword',
					'api/feedback',
					'api/saveFeedback',
					'api/markClientFeedback',
					'api/markTrainerFeedback'
				)
			)
		);
	}
	
	public function actionResources()
	{
		$result = new ApiResource();
		

		$trainer = new ApiPoint();
		$trainer->path = '/trainer.{format}';
		$trainer->description = 'Managing Trainers';
		
		$result->addApi($trainer);
		$client = new ApiPoint();
		$client->path = '/client.{format}';
		$client->description = 'Managing Clients';
		
		$result->addApi($client);
		$client_access_token = new ApiPoint();
		$client_access_token->path = '/client_access_token.{format}';
		$client_access_token->description = 'Managing Client Access tokens';
		
		$result->addApi($client_access_token);
		$account = new ApiPoint();
		$account->path = '/account.{format}';
		$account->description = 'Managing Accounts';
		
		$result->addApi($account);
		$location = new ApiPoint();
		$location->path = '/location.{format}';
		$location->description = 'Managing Locations';
		
		$result->addApi($location);

//		$goal = new ApiPoint();
//		$goal->path = '/goal.{format}';
//		$goal->description = 'Managing Goals';
//		
//		$result->addApi($goal);

		$trainingplan = new ApiPoint();
		$trainingplan->path = '/trainingplan.{format}';
		$trainingplan->description = 'Managing Trainingplans';
		
		$result->addApi($trainingplan);
		
		$metric = new ApiPoint();
		$metric->path = '/metric.{format}';
		$metric->description = 'Managing Metrics';
		$result->addApi($metric);

		$training = new ApiPoint();
		$training->path = '/training.{format}';
		$training->description = 'Managing Trainings';
		
		$result->addApi($training);
		$exerciseset = new ApiPoint();
		$exerciseset->path = '/exerciseset.{format}';
		$exerciseset->description = 'Managing ExerciseSets';
		
		$result->addApi($exerciseset);
		$review = new ApiPoint();
		$review->path = '/review.{format}';
		$review->description = 'Managing Reviews';
		
		$result->addApi($review);
		$review_heart_rate_timeseries = new ApiPoint();
		$review_heart_rate_timeseries->path = '/review_heart_rate_timeseries.{format}';
		$review_heart_rate_timeseries->description = 'Managing Review Heart Rate Timeseriess';
		
		$result->addApi($review_heart_rate_timeseries);
		$exercise = new ApiPoint();
		$exercise->path = '/exercise.{format}';
		$exercise->description = 'Managing Exercises';
		
		$result->addApi($exercise);
		$exercise_pictures = new ApiPoint();
		$exercise_pictures->path = '/exercise_pictures.{format}';
		$exercise_pictures->description = 'Managing Exercise Picturess';
		
		$result->addApi($exercise_pictures);
		$content = new ApiPoint();
		$content->path = '/content.{format}';
		$content->description = 'Managing Contents';
		
		$result->addApi($content);
		$offer = new ApiPoint();
		$offer->path = '/offer.{format}';
		$offer->description = 'Managing Offers';
		
		$result->addApi($offer);
		$preference = new ApiPoint();
		$preference->path = '/preference.{format}';
		$preference->description = 'Managing Preferences';
		
		$result->addApi($preference);
		$language = new ApiPoint();
		$language->path = '/language.{format}';
		$language->description = 'Managing Languages';
		
		$result->addApi($language);
		$file = new ApiPoint();
		$file->path = '/file.{format}';
		$file->description = 'Managing Files';
		
		$result->addApi($file);
		$translation = new ApiPoint();
		$translation->path = '/translation.{format}';
		$translation->description = 'Managing Translations';
		
		$result->addApi($translation);
		
		$performance_test = new ApiPoint();
		$performance_test->path = '/performance_test.{format}';
		$performance_test->description = 'Managing Performance Tests';
		
		$result->addApi($translation);

		$this->_sendResponse(200, $result);
	}
	
	public function actionDoc() 
	{
		if (in_array($_GET['model'], $this->_models)) {
			$this->_sendResponse(200, ApiOperationFactory::getApiForModel($_GET['model']));
		} else {
			$this->_sendResponse(501, sprintf(
								'Error: Api docs not supported for model <b>%s</b>', $_GET['model']));
		}
	}
	
	public function actionModels()
	{
		$result = array();
		foreach ($this->_models as $model) {
			$result[$model] = Helper::getModel($model)->getModelDescription();
		}
		$this->_sendResponse(200, $result);
	}
	
	public function actionRecording()
	{
		$callback = Yii::app()->getRequest()->getParam('callback', false);
		$result = array();
		$limit = 10;
		for ($i = 0; $i < $limit; $i++) {
			$obj = new stdClass();
			$obj->address = 'belt_' . $i;
			$obj->heart_rate = rand(80, 150);
			$result[] = $obj;
		}
		if ($callback) {
			$this->_sendResponse(200, "$callback(" . json_encode($result) . ");", 'text/javascript', false);
		} else {
			$this->_sendResponse(200, $result);
		}
	}
	
	public function actionSaveRecording()
	{
		$data = $this->_getRequestParams();
		$timeseries = json_decode($data['timeseries'], true);
		unset($data['timeseries']);
		$review = new Review();
		$review->attributes = $data;
		if ($review->save()) {
			foreach ($timeseries as $one) {
				$m = new Reviewheartratetimeseries;
				$m->attributes = $one;
				//$m->value = $review->training->client->min_heart_rate + ($m->value - $review->training->client->min_heart_rate) * $review->getMediane();
				$m->review_id = $review->id;
				$m->save();
			}
			$this->_sendResponse(200, $review);
		} else {
			$errors = array();
			foreach ($review->errors as $attr_errors) {
				foreach ($attr_errors as $attr_error) {
					$errors[] = $attr_error;
				}
			}
			$this->_sendResponse(500, array('errors' => $errors));
		}
	}
	
	public function actionGenerateChart() {
		$review_id = Yii::app()->getRequest()->getParam('review_id', false);
		if ($review_id) {
			$review = Review::model()->findByPk($review_id);
			if ($review) {
				$review->generateChart();
			} else {
				$this->_sendResponse(200, 'Chart generated', 'text/javascript');
			}
		} else {
			$this->_sendResponse(400, 'Missing required data');
			return;
		}
	}
	
	public function actionSaveRatesAndBelt() {
		$params = $this->_getRequestParams();
		$this->_checkAccess(@$params['client_id']);
		$client = Client::model()->findByPk(@$params['client_id']);
		if (!$client) {
			$this->_sendResponse(400, 'Client not found');
			return;
		}
		
		if (isset($params['device']) && $params['device']) {
			if (!$client->account) {
				$client->account = new Account();
				$client->account->client_id = $client->id;
			}
			$client->account->device = $params['device'];
			$client->account->save();
		}
		if (isset($params['max_heart_rate']) && $params['max_heart_rate']) {
			$client->max_heart_rate = $params['max_heart_rate'];
		}
		if (isset($params['min_heart_rate']) && $params['min_heart_rate']) {
			$client->min_heart_rate = $params['min_heart_rate'];
		}
		$client->save();
		$this->_sendResponse(200, 'ok');
	}
	
	public function actionSaveSerialAvalibility() {
		$params = $this->_getRequestParams();
		$this->_checkAccess();
		$form = new SerialAvalibilityForm();
		$form->attributes = $params;
		$form->validate();
		if ($form->hasErrors()) {
			$message = array();
			foreach ($form->getErrors() as $error) {
				foreach ($error as $one) {
					$message[] = $one;
				}
			}
			$this->_sendResponse(400, implode('<br/>',$message));
		} else {
			$form->create();
			$this->_sendResponse(200, 'ok');
		}
	}
	
	public function actionSaveIntervalSettings() {
		$params = $this->_getRequestParams();
		$this->_checkAccess();
		$client = Client::model()->findbyPk($params['client_id']);
		if ($client) {
			$client->account->interval_distance = $params['interval_distance'];
			$client->account->interval_repeats= $params['interval_repeats'];
			$client->account->interval_zone = $params['interval_zone'];
			$client->account->save();
			$this->_sendResponse(200, 'ok');
		} else {
			$this->_sendResponse(404, 'Client not found');
		}
		
	}
	
	public function actionSaveRunning() {
		$params = $this->_getRequestParams();
		$client = Client::model()->findByPk(@$params['client_id']);
		if (!$client) {
			$this->_sendResponse(400, 'Client not found');
			return;
		}
		$training = new Training();
		$training->client_id = $params['client_id'];
		$training->type_id = $params['type_id'];
		$training->date = date('Y-m-d', round($params['start'] / 1000));
		$training->starttime = date('H:i:s', round($params['start'] / 1000));
		$training->duration = (int)$params['duration'];
		$training->status = 'attended';
		$training->no_email = true;
		if ($training->save()) {
			$review = new Review();
			$review->create_feedback = false;
			$review->training_id = $training->id;
			$review->training_type = $params['type'];
			$review->type = $params['intencity'];
			$review->distance = $params['distance'];
			$review->speed = $params['speed'];
			
			if ($review->save()) {
				$duration = '';
				$rate = 0;
				$sort = 0;
				$data = CJSON::decode($params['data']);
				$insert = 'insert into tbl_review_heart_rate_timeseries (timestamp,	value, sort, review_id) values ';
				$inser_values = array();
				foreach ($data as $timeseries) {
					$inser_value = '('
						. '"' . $timeseries['timestamp'] . '",'
						. $timeseries['value']  . ','
						. $sort . ','
						. $review->id . ')';
					$inser_values[] = $inser_value;
					$sort++;

					$duration = $timeseries['timestamp'];
					if ($params['type'] == 'fitness') {
						if (!$rate || $timeseries['value'] < $rate) {
							$rate = $timeseries['value'];
						}
					} else {
						$rate += $timeseries['value'];
					}
				}
				$insert .= join(',', $inser_values);
				$command=Yii::app()->db->createCommand($insert);
				$command->execute();
				$review->duration = $duration;
				if ($params['type'] == 'fitness') {
					$review->heart_rate = $rate;
					$review->training->client->min_heart_rate = $rate;
					$review->training->client->save();
					if (count($review->training->client->metrics)) {
						$review->training->client->metrics[0]->calm_pulse = $rate;
						$review->training->client->metrics[0]->save();
					} else {
						$metric = new Metric;
						$metric->calm_pulse = $rate;
						$metric->date = date('Y-m-d H:i:s');
						$metric->client_id = $review->training->client->id;
						$metric->save();
					}
				} else {
					$review->heart_rate = (int)($rate / $sort+1);
				}
				$review->save();
				$review->createFeedbackCircle();
				$this->_sendResponse(200, $review);
			} else {
				$errors = array();
				foreach ($review->errors as $attr_errors) {
					foreach ($attr_errors as $attr_error) {
						$errors[] = $attr_error;
					}
				}
				$this->_sendResponse(500, array('errors' => $errors));
			}
		} else {
			$errors = array();
			foreach ($training->errors as $attr_errors) {
				foreach ($attr_errors as $attr_error) {
					$errors[] = $attr_error;
				}
			}
			$this->_sendResponse(500, array('errors' => $errors));
		}
	}
	
	public function actionChangePassword() {
		$this->_checkAccess();
		$newPassword = Yii::app()->getRequest()->getParam('password');
		if ($newPassword) {
			$this->current_client->clientpasscode = Yii::app()->getRequest()->getParam('password');
			$this->current_client->save();
		}
		$this->_sendResponse(200, 'ok');
	}
	
	public function actionGetIcal() {
		$training_id = Yii::app()->getRequest()->getParam('id');
		$training = Training::model()->findByPk($training_id);
		if ($training) {
			Yii::app()->request->sendFile('Appointment.ics', $training->ical()->createCalendar());
		} else {
			throw new CHttpException(404);
		}
	}
	
	public function actionSettings()
	{
		$key = Yii::app()->getRequest()->getParam('key', false);
		if ($key) {
			$this->_sendResponse(200, array($key => Yii::app()->cfg->getItem($key)));
		} else {
			$this->_sendResponse(400, 'Missing required data');
			return;
		}
	}
	
	public function actionAvaliability()
	{
		$trainers = Yii::app()->getRequest()->getParam('trainers', false);
		$location_id = Yii::app()->getRequest()->getParam('location_id', false);
		if (!$trainers || !$location_id) {
			$this->_sendResponse(400, 'Missing required data');
			return;
		}
		$trainer_ids = explode(',', $trainers);
		$result = array();
		$from = Yii::app()->getRequest()->getParam('from', false);
		$to = Yii::app()->getRequest()->getParam('to', false);
		foreach ($trainer_ids as $trainer_id) {
			$trainer = Trainer::model()->findByPk($trainer_id);
			if ($trainer) {
				$res = new stdClass();
				$res->id = $trainer->id;
				$res->initials = $trainer->getInitials();
				$res->color = $trainer->color;
				$res->avaliability = $trainer->getLocationAvailability($location_id, $from, $to);
				$result[] = $res;
			}
		}
		$this->_sendResponse(200, $result);
	}
	
	public function actionFullAvaliability()
	{
		$trainers = Yii::app()->getRequest()->getParam('trainers', false);
		if (!$trainers) {
			$this->_sendResponse(400, 'Missing required data');
			return;
		}
		$result = array();
		$trainer_ids = explode(',', $trainers);
		$from = Yii::app()->getRequest()->getParam('from', false);
		$to = Yii::app()->getRequest()->getParam('to', false);
		foreach ($trainer_ids as $trainer_id) {
			$trainer = Trainer::model()->findByPk($trainer_id);
			if ($trainer) {
				$res = new stdClass();
				$res->id = $trainer->id;
				$res->color = $trainer->color;
				$res->avaliability = $trainer->getAvailability($from, $to);
				$result[] = $res;
			}
		}
		$this->_sendResponse(200, $result);
	}
	
	public function actionToken()
	{
		if (Yii::app()->getRequest()->getPost('e_mail')) {
			$client = Client::model()->active()->findByAttributes(array('e_mail' => Yii::app()->getRequest()->getPost('e_mail'), 'clientpasscode' => Yii::app()->getRequest()->getPost('clientpasscode')));
		} else {
			$client = Client::model()->active()->findByAttributes(array('clientpasscode' => Yii::app()->getRequest()->getPost('clientpasscode')));
		}
		if ($client) {
			if (!$client->preference) {
				$client->preference = new Preference;
				$client->preference->preferred_trainer_rel = Trainer::model()->find()->id;
				$client->preference->preferred_location_rel = Location::model()->find()->id;
				$client->preference->preferred_language_rel = Language::model()->find()->id;
				$client->preference->client_id = $client->id;
				$client->preference->save();
			}
			if (!$client->account) {
				$client->account = new Account();
				$client->account->client_id = $client->id;
				$client->account->save();
			}
			$obj = new stdClass();
			$obj->client = clone $client;
			$obj->preference_id = $client->preference->id;
			$obj->lang = $client->preference->preferred_language->language;
			$obj->account = $client->account;
			$obj->token = Clientaccesstoken::generate($client);
			$this->_sendResponse(200, $obj);
		} else {
			$this->_sendResponse(401, 'Login failed - please check your access data');
		}
	}
	
	public function actionLoginTrainer()
	{
		$trainer = Trainer::model()->active()->findByAttributes(array('passcode' => Yii::app()->getRequest()->getPost('passcode')));
		if ($trainer) {
			$obj = new stdClass();
			$obj->trainer = clone $trainer;
			$obj->trainer->passcode = md5(ApiAccessFilter::$salt . $obj->trainer->passcode);
			$this->_sendResponse(200, $obj);
		} else {
			$this->_sendResponse(401, 'Login failed - please check your access data');
		}
	}
	
	public function actionCancelTraining()
	{
		$client = Client::model()->findByPk(Yii::app()->getRequest()->getParam('client_id'));
		$this->_checkAccess(Yii::app()->getRequest()->getParam('client_id'));
		if ($client) {
			$training = Training::model()->findByPk(Yii::app()->getRequest()->getParam('id'));
			try {
				$training->cancel($client);
			} catch (Exception $e) {
				$this->_sendResponse(500, $e->getMessage());
			}
		} else {
			$this->_sendResponse(500, 'You cannot cancel this training');
		}
	}
	
	public function actionCancelTrainingTrainer()
	{
		$trainer = Trainer::model()->findByPk(Yii::app()->getRequest()->getParam('trainer_id'));
		if ($trainer) {
			$training = Training::model()->findByPk(Yii::app()->getRequest()->getParam('id'));
			try {
				$training->cancel($trainer);
			} catch (Exception $e) {
				$this->_sendResponse(500, $e->getMessage());
			}
		} else {
			$this->_sendResponse(500, 'You cannot cancel this training');
		}
	}
	
	public function actionInviteTraining()
	{
		$client = Client::model()->findByPk(Yii::app()->getRequest()->getParam('client_id'));
		$this->_checkAccess(Yii::app()->getRequest()->getParam('client_id'));
		if ($client) {
			$training = Training::model()->findByPk(Yii::app()->getRequest()->getParam('id'));
			$message = new YiiMailMessage;
			$body = "Time: {$training->getModelDisplay()}<br/>Ort: {$training->location->name}<br/><br/>" . Yii::app()->getRequest()->getParam('message');
			$message->setBody($body, 'text/html');
			$message->subject = $training->type->name_en . ' - ' . $training->getModelDisplay();
			$message->addTo(Yii::app()->getRequest()->getParam('email'));
			$message->from = Yii::app()->params['adminEmail'];
			
			$v = new vcalendar( array( 'unique_id' => 'sihltraining'));
			$v->setMethod('REQUEST');
			$e = $training->asICalEvent($v);
			$e->setAttendee(Yii::app()->getRequest()->getParam('email'), array('ROLE' => 'REQ-PARTICIPANT', 'PARTSTAT' => 'NEEDS-ACTION', 'RSVP' => true));
			$e->setDescription(Yii::app()->getRequest()->getParam('message'));
			
			$alarm = $e->newComponent('valarm');
			$alarm->setAction('DISPLAY');
			$alarm->setDescription('REMINDER');
			$alarm->setTrigger('-PT15M', array('RELATED' => true));
			
			$attachment = Swift_Attachment::newInstance()
				->setFilename('invite.ics')
				->setContentType('text/calendar')
				->setBody($v->createCalendar())
				;
			$message->attach($attachment);
			Yii::app()->mail->send($message);
			$this->_sendResponse(200, array());
		} else {
			$this->_sendResponse(500, 'You cannot perform this action');
		}
	}
	
	public function actionInviteTrainingTrainer()
	{
		$trainer = Trainer::model()->findByPk(Yii::app()->getRequest()->getParam('trainer_id'));
		if ($trainer) {
			$training = Training::model()->findByPk(Yii::app()->getRequest()->getParam('id'));
			$message = new YiiMailMessage;
			$body = "Time: {$training->getModelDisplay()}<br/>Ort: {$training->location->name}<br/><br/>" . Yii::app()->getRequest()->getParam('message');
			$message->setBody($body, 'text/html');
			$message->subject = $training->type->name_en . ' - ' . $training->getModelDisplay();
			$message->addTo(Yii::app()->getRequest()->getParam('email'));
			$message->from = Yii::app()->params['adminEmail'];
			
			$v = new vcalendar( array( 'unique_id' => 'sihltraining'));
			$v->setMethod('REQUEST');
			$e = $training->asICalEvent($v);
			$e->setAttendee(Yii::app()->getRequest()->getParam('email'), array('ROLE' => 'REQ-PARTICIPANT', 'PARTSTAT' => 'NEEDS-ACTION', 'RSVP' => true));
			$e->setDescription(Yii::app()->getRequest()->getParam('message'));
			
			$alarm = $e->newComponent('valarm');
			$alarm->setAction('DISPLAY');
			$alarm->setDescription('REMINDER');
			$alarm->setTrigger('-PT15M', array('RELATED' => true));
			
			$attachment = Swift_Attachment::newInstance()
				->setFilename('invite.ics')
				->setContentType('text/calendar')
				->setBody($v->createCalendar())
				;
			$message->attach($attachment);
			Yii::app()->mail->send($message);
			$this->_sendResponse(200, array());
		} else {
			$this->_sendResponse(500, 'You cannot perform this action');
		}
	}
	
	public function actionSendFile()
	{
		$trainer_id = Yii::app()->getRequest()->getParam('trainer_id', false);
		if ($trainer_id) {
			$trainer = Trainer::model()->findByPk($trainer_id);
			if ($trainer) {
				$file = File::model()->findByPk(Yii::app()->getRequest()->getParam('id'));
				if (!$file) {
					$this->_sendResponse(404, 'File not found');
					return;
				}
				$message = new YiiMailMessage;
				$body = Yii::app()->getRequest()->getParam('message', '');
				$message->setBody($body, 'text/plain');
				$message->subject = 'File:' . $file->getModelDisplay();
				$message->addTo(Yii::app()->getRequest()->getParam('email'));
				$message->from = $trainer->e_mail ? $trainer->e_mail : Yii::app()->params['adminEmail'];

				$fileContent = Yii::app()->CURL->run($file->file);

				$attachment = Swift_Attachment::newInstance()
					->setFilename(basename($file->file))
					->setContentType('text/calendar')
					->setBody($fileContent)
					;
				$message->attach($attachment);
				Yii::app()->mail->send($message);
			} else {
				$this->_sendResponse(403, 'You cannot perform this action');
			}
		} else {
			$client = Client::model()->findByPk(Yii::app()->getRequest()->getParam('client_id'));
			$this->_checkAccess(Yii::app()->getRequest()->getParam('client_id'));
			if ($client) {
				$file = File::model()->findByPk(Yii::app()->getRequest()->getParam('id'));
				if (!$file) {
					$this->_sendResponse(404, 'File not found');
					return;
				}
				$message = new YiiMailMessage;
				$body = Yii::app()->getRequest()->getParam('message', '');
				$message->setBody($body, 'text/plain');
				$message->subject = 'File:' . $file->getModelDisplay();
				$message->addTo(Yii::app()->getRequest()->getParam('email'));
				$message->from = $client->e_mail ? $client->e_mail : Yii::app()->params['adminEmail'];

				$fileContent = Yii::app()->CURL->run($file->file);

				$attachment = Swift_Attachment::newInstance()
					->setFilename(basename($file->file))
					->setContentType('text/calendar')
					->setBody($fileContent)
					;
				$message->attach($attachment);
				Yii::app()->mail->send($message);
			} else {
				$this->_sendResponse(403, 'You cannot perform this action');
			}
		}
	}
	
	public function actionNextTrainerAppointment()
	{
		$trainer_id = Yii::app()->getRequest()->getParam('trainer_id');
		$date = Yii::app()->getRequest()->getParam('date');
		$time = Yii::app()->getRequest()->getParam('time');
		if (!$trainer_id || !$date || !$time) {
			$this->_sendResponse(400, 'Missing required data');
			return;
		}
		$criteria = new CDbCriteria;
		$criteria->condition = 'trainer_id = :trainer_id and (date > :date or (date = :date and addtime(starttime, CONCAT("00:", duration,  ":00")) > :time)) and status = "booked"';
		$criteria->order = 'date, starttime';
		$criteria->params = array(
			'trainer_id' => $trainer_id,
			'date' => $date,
			'time' => $time,
		);
		$next = Training::model()->find($criteria);
		if (!$next) {
			$this->_sendResponse(200, array());
		}
		$result = new stdClass();
		foreach ($next->attributes as $key => $value) {
			$result->{$key} = $value;
		}
		$result->client = new stdClass;
		foreach ($next->client->attributes as $key => $value) {
			$result->client->{$key} = $value;
		}
		$result->client->account = new stdClass;
		if ($next->client->account) {
			foreach ($next->client->account->attributes as $key => $value) {
				$result->client->account->{$key} = $value;
			}
		}
		$this->_sendResponse(200, array($result));
	}
	
	public function actionSendPlan()
	{
		$trainingPlan = TrainingPlan::model()->findByPk(Yii::app()->getRequest()->getParam('plan_id', false));
		if ($trainingPlan) {
			$message = new YiiMailMessage;
			$body = 'PDF file for training plan ' . $trainingPlan->getModelDisplay();
			$message->setBody($body, 'text/html');
			$message->subject = 'Training Plan PDF';
			$message->addTo(Yii::app()->getRequest()->getParam('email'));
			$message->from = Yii::app()->params['adminEmail'];
			
			$tmpfile = false;
			if(!ini_get('allow_url_fopen') && $trainingPlan->client && $trainingPlan->client->foto) {
				$ch = curl_init();
				curl_setopt ($ch, CURLOPT_URL, $trainingPlan->client->foto);
				curl_setopt ($ch, CURLOPT_RETURNTRANSFER, 1);
				curl_setopt ($ch, CURLOPT_CONNECTTIMEOUT, 10);
				$tmpfile = tempnam(Yii::getPathOfAlias('application.runtime'), 'tmp');
				file_put_contents($tmpfile, curl_exec($ch));
				curl_close($ch);
				$trainingPlan->client->foto = $tmpfile;
			}
			
			$html2pdf = Yii::app()->ePdf->HTML2PDF();
			$html2pdf->WriteHTML($this->renderPartial('//trainingplan/pdf', array('model' => $trainingPlan), true));
			
			$attachment = Swift_Attachment::newInstance()
				->setFilename('trainingplan_' . $trainingPlan->getModelDisplay() .'.pdf')
				->setContentType('application/pdf')
				->setBody($html2pdf->Output('', true))
				;
			
			if($tmpfile) {
				@unlink($tmpfile);
			}
			$message->attach($attachment);
			Yii::app()->mail->send($message);
			$this->_sendResponse(200, array());
		} else {
			$this->_sendResponse(500, 'You cannot perform this action');
		}
	}
	
	public function actionSendAnamnese()
	{
		$this->_checkAccess(Yii::app()->getRequest()->getParam('client_id'));
		$anamnese = ClientAnamnese::model()->findByPk(Yii::app()->getRequest()->getParam('client_id', false));
		if (!$anamnese) {
			$anamnese = new ClientAnamnese;
			$anamnese->client_id = Yii::app()->getRequest()->getParam('client_id', false);
		}
		$message = new YiiMailMessage;
		$body = 'Anamnese PDF file for ' . $anamnese->client->getModelDisplay();
		$message->setBody($body, 'text/html');
		$message->subject = 'Anamnese PDF';
		$message->addTo(Yii::app()->getRequest()->getParam('email'));
		$message->from = Yii::app()->params['adminEmail'];
			
		$html2pdf = Yii::app()->ePdf->HTML2PDF();
		$html2pdf->WriteHTML($this->renderPartial('//client/anamnesepdf', array('anamnese' => $anamnese), true));
			
		$attachment = Swift_Attachment::newInstance()
			->setFilename('anamnese_' . $anamnese->client->getModelDisplay() .'.pdf')
			->setContentType('application/pdf')
			->setBody($html2pdf->Output('', true))
		;
			
		$message->attach($attachment);
		Yii::app()->mail->send($message);
		$this->_sendResponse(200, array());
	}
	
	public function actionService() 
	{
		$service = Service::model()->findByAttributes(array('model' => $_GET['model'], 'service_alias' => $_GET['service']));
		if (!$service) {
			$this->_sendResponse(501, sprintf(
								'Error: Service %s is not supported for model %s', $_GET['service'], $_GET['model']));
			Yii::app()->end();
		}
		
		$params = $service->getParamArray();
		$paramValues = array();
		foreach ($params as $name => $required) {
			if ($required && !isset($_GET[$name])) {
				$this->_sendResponse(501, sprintf(
								'Error: Required parameter %s not defined', $name));
			}
			$paramValues[$name] = isset($_GET[$name]) ? $_GET[$name] : null;
		}
		try {
			$this->_sendResponse(200, $service->getData($paramValues));
		} catch (Exception $e) {
			$this->_sendResponse(500, $e->getMessage());
		}
	}
	
	public function actionServiceList()
	{
		$this->_sendResponse(200, Service::model()->published()->findAll());
	}
	
	public function actionCredits() {
		$client_id = Yii::app()->request->getParam('client_id');
		$this->_checkAccess($client_id);
		$client = Client::model()->findByPk($client_id);
		$credits = $client->credits;
		$result = array();
		foreach ($credits as $credit) {
			if ($credit->startdate) {
				if (strtotime($credit->startdate) > time()) {
					continue;
				}
			}
			$result[] = array(
				'training_type_id' => $credit->training_type_id,
				'service' => $credit->training_type->service,
				'paid' => $credit->paid,
				'attended' => $credit->attended,
				'abbonement' => $credit->abbonement ? $credit->abbonement->getModelDisplay() : $credit->training_type->name_en,
				'expires'  => $credit->expires,
			);
		}
		$this->_sendResponse(200, $result);
	}
	
	public function actionTotalCredits() {
		$client_id = Yii::app()->request->getParam('client_id');
		$this->_checkAccess($client_id);
		$client = Client::model()->findByPk($client_id);
		$this->_sendResponse(200, $client->getCreditTotals());
	}
	
	public function actionFeedback() {
		$client_id = Yii::app()->request->getParam('client_id');
		$this->_checkAccess($client_id);
		$client = Client::model()->findByPk($client_id);
		$this->_sendResponse(200, $client->getFeedbackList());
	}
	
	public function actionSaveFeedback() {
		$client_id = Yii::app()->request->getParam('client_id', null);
		$this->_checkAccess($client_id);
		$feedback = new Feedback;
		$feedback->client_id = $client_id;
		$feedback->trainer_id = Yii::app()->request->getParam('trainer_id', null);
		$feedback->text = Yii::app()->request->getParam('text', null);
		$feedback->read_client = (int)Yii::app()->request->getParam('read_client');
		$feedback->read_trainer = (int)Yii::app()->request->getParam('read_trainer');
		if ($feedback->save()) {
			$this->_sendResponse(200, $feedback);
		} else {
			$errors = array();
			foreach ($model->errors as $attr_errors) {
				foreach ($attr_errors as $attr_error) {
					$errors[] = $attr_error;
				}
			}
			$this->_sendResponse(500, array('errors' => $errors));
		}
	}
	
	public function actionMarkClientFeedback() {
		$client_id = Yii::app()->request->getParam('client_id', null);
		$feedbacks = Feedback::model()->findAllByAttributes(array('client_id' => $client_id, 'read_client' => 0));
		foreach ($feedbacks as $feedback) {
			$feedback->read_client = 1;
			$feedback->save();
		}
		$this->_sendResponse(200, 'ok');
	}
	public function actionMarkTrainerFeedback() {
		$client_id = Yii::app()->request->getParam('client_id', null);
		$feedbacks = Feedback::model()->findAllByAttributes(array('client_id' => $client_id, 'read_trainer' => 0));
		foreach ($feedbacks as $feedback) {
			$feedback->read_trainer = 1;
			$feedback->save();
		}
		$this->_sendResponse(200, 'ok');
	}
	
	// Actions
	public function actionList()
	{
		if (in_array($_GET['model'], $this->_models)) {
			$models = Helper::getModel($_GET['model'])->findAll();
		} else {
			$this->_sendResponse(501, sprintf(
								'Error: Mode <b>list</b> is not implemented for model <b>%s</b>', $_GET['model']));
			Yii::app()->end();
		}
		if (empty($models)) {
			$this->_sendResponse(200, array());
		} else {
			$rows = array();
			foreach ($models as $model) {
				$attributes = $model->attributes;
				foreach ($attributes as $key => $value) {
					if (method_exists($model, 'get' . ucfirst($key))) {
						$name = 'get' . ucfirst($key);
						$attributes[$key] = $model->$name();
						$attributes[$key . '_key'] = $model->$key;
					}
					if (in_array($key, $this->_restrictedAttributesView)) {
						unset($attributes[$key]);
					}
				} 
				$rows[] = $attributes;
			}
			$this->_sendResponse(200, $rows);
		}
	}

	public function actionView()
	{
		if (!isset($_GET['id']))
			$this->_sendResponse(500, 'Error: Parameter <b>id</b> is missing');

		if (in_array($_GET['model'], $this->_models)) {
			$model = Helper::getModel($_GET['model'])->findByPk($_GET['id']);
		} else {
			$this->_sendResponse(501, sprintf(
								'Mode <b>view</b> is not implemented for model <b>%s</b>', $_GET['model']));
			Yii::app()->end();
		}
		
		if (is_null($model)) {
			$this->_sendResponse(404, 'No Item found with id ' . $_GET['id']);
		} else {
			$attributes = $model->attributes;
			foreach ($attributes as $key => $value) {
				if (in_array($key, $this->_restrictedAttributesView)) {
					unset($attributes[$key]);
				}
			}
			$this->_sendResponse(200, $model);
		}
	}

	public function actionCreate()
	{
		switch ($_GET['model']) {
			case 'trainer':
				$model = new Trainer;
				break;
			case 'trainer_avaliability':
				$model = new TrainerAvailability;
				break;
			case 'client':
				$model = new Client;
				break;
			case 'client_access_token':
				$model = new Clientaccesstoken;
				break;
			case 'account':
				$model = new Account;
				break;
			case 'location':
				$model = new Location;
				break;
//			case 'goal':
//				$model = new Goal;
//				break;
			case 'metric':
				$model = new Metric;
				break;
			case 'training':
				$model = new Training;
				break;
			case 'trainingplan':
				$model = new TrainingPlan;
				break;
			case 'exerciseset':
				$model = new Exerciseset;
				break;
			case 'review':
				$model = new Review;
				break;
			case 'review_heart_rate_timeseries':
				$model = new Reviewheartratetimeseries;
				break;
			case 'exercise':
				$model = new Exercise;
				break;
			case 'exercise_pictures':
				$model = new Exercisepictures;
				break;
			case 'content':
				$model = new Content;
				break;
			case 'offer':
				$model = new Offer;
				break;
			case 'preference':
				$model = new Preference;
				break;
			case 'language':
				$model = new Language;
				break;
			case 'file':
				$model = new File;
				break;
			case 'translation':
				$model = new Translation;
				break;
			case 'performance_test':
				$model = new PerformanceTest;
				break;
			case 'anamnese':
				$model = new ClientAnamnese;
				break;
			default:
				$this->_sendResponse(501, sprintf('Mode <b>create</b> is not implemented for model <b>%s</b>', $_GET['model']));
				Yii::app()->end();
				return;
		}
		$params = $this->_getRequestParams();
		
		foreach ($params as $var => $value) {
			if ($model->hasAttribute($var) && !in_array($var, $this->_restrictedAttributes)) {
				$model->$var = $value;
			}
		}
		if ($_GET['model'] == 'training' && !$model->checkAvalible() && $params['createAvaliability']) {
				$avaliability = new TrainerAvailability;
				$avaliability->location_id = $params['location_id'];
				$avaliability->trainer_id = $params['trainer_id'];
				$avaliability->training_type_id = $params['type_id'];
				$avaliability->date = $params['date'];
				$avaliability->from = date('H:i:s', strtotime($params['starttime']));;
				$avaliability->to = date('H:i:s', strtotime('+' . $model->type->duration . 'minutes', strtotime($params['starttime'])));
				$avaliability->save();
			}
		if ($model->save()) {
			$this->_sendResponse(200, $model);
		} else {
			$errors = array();
			foreach ($model->errors as $attr_errors) {
				foreach ($attr_errors as $attr_error) {
					$errors[] = $attr_error;
				}
			}
			$this->_sendResponse(500, array('errors' => $errors));
		}
	}

	public function actionUpdate()
	{
		
		if (in_array($_GET['model'], $this->_models)) {
			$model = Helper::getModel($_GET['model'])->findByPk($_GET['id']);
		} else {
			$this->_sendResponse(501, sprintf(
								'Error: Mode <b>update</b> is not implemented for model <b>%s</b>', $_GET['model']));
			Yii::app()->end();
		}
		if ($model === null) {
			$this->_sendResponse(400, sprintf("Error: Didn't find any model <b>%s</b> with ID <b>%s</b>.", $_GET['model'], $_GET['id']));
		}

		foreach ($this->_getRequestParams() as $var => $value) {
			if ($model->hasAttribute($var) && !in_array($var, $this->_restrictedAttributes)) {
				$model->$var = $value;
			}
		}
		// Try to save the model
		if ($model->save()) {
			$this->_sendResponse(200, $model);
		} else {
			$errors = array();
			foreach ($model->errors as $attr_errors) {
				foreach ($attr_errors as $attr_error) {
					$errors[] = $attr_error;
				}
			}
			$this->_sendResponse(500, array('errors' => $errors));
		}
	}

	public function actionDelete()
	{
		if (in_array($_GET['model'], $this->_models)) {
			$model = Helper::getModel($_GET['model'])->findByPk($_GET['id']);
		} else {
			$this->_sendResponse(501, sprintf(
								'Error: Mode <b>delete</b> is not implemented for model <b>%s</b>', $_GET['model']));
			Yii::app()->end();
		}
		// Was a model found? If not, raise an error
		if ($model === null) {
			$this->_sendResponse(400, sprintf("Error: Didn't find any model <b>%s</b> with ID <b>%s</b>.", $_GET['model'], $_GET['id']));
		}

		// Delete the model
		$num = $model->delete();
		if ($num > 0) {
			$this->_sendResponse(200, $num);	//this is the only way to work with backbone
		} else {
			$this->_sendResponse(500, sprintf("Error: Couldn't delete model <b>%s</b> with ID <b>%s</b>.", $_GET['model'], $_GET['id']));
		}
	}

	private function _sendResponse($status = 200, $body = '', $content_type = 'text/html', $wrapBody = true)
	{
		$status_header = 'HTTP/1.1 ' . $status . ' ' . $this->_getStatusCodeMessage($status);
		header($status_header);
		header('Content-type: ' . $content_type);
		$headers = $this->_getHeaders();
		if (isset($headers['Origin'])) {
			header('Access-Control-Allow-Origin: ' . $headers['Origin']);
		} else {
			header('Access-Control-Allow-Origin: *');
		}
		header('Access-Control-Allow-Headers: X-Requested-With');
		header('Access-Control-Allow-Credentials: true');
		

		if ($body != '') {
			if (is_string($body) && $wrapBody) {
				$body = array('message' => $body);
			}
			ob_start("ob_gzhandler");
			if ($wrapBody) {
				echo CJSON::encode($body);
			} else {
				echo $body;
			}
			ob_end_flush();
			Yii::app()->end();
		} else {
			$this->layout = '//layouts/column1';
			$message = '';

			switch ($status) {
				case 401:
					$message = 'You must be authorized to view this page.';
					break;
				case 404:
					$message = 'The requested URL ' . $_SERVER['REQUEST_URI'] . ' was not found.';
					break;
				case 500:
					$message = 'The server encountered an error processing your request.';
					break;
				case 501:
					$message = 'The requested method is not implemented.';
					break;
			}

			// servers don't always have a signature turned on
			// (this is an apache directive "ServerSignature On")
			$signature = ($_SERVER['SERVER_SIGNATURE'] == '') ? $_SERVER['SERVER_SOFTWARE'] . ' Server at ' . $_SERVER['SERVER_NAME'] . ' Port ' . $_SERVER['SERVER_PORT'] : $_SERVER['SERVER_SIGNATURE'];

			$this->render('body', array(
				'status' => $this->_getStatusCodeMessage($status),
				'message' => $message,
				'signature' => $signature
			));
		}
	}

	private function _getStatusCodeMessage($status)
	{
		$codes = Array(
			200 => 'OK',
			400 => 'Bad Request',
			401 => 'Unauthorized',
			402 => 'Payment Required',
			403 => 'Forbidden',
			404 => 'Not Found',
			500 => 'Internal Server Error',
			501 => 'Not Implemented',
		);
		return (isset($codes[$status])) ? $codes[$status] : '';
	}
	
	protected function _getHeaders() {
		if (function_exists('getallheaders')) {
			return getallheaders();
		} else {
			$headers = array();
			foreach($_SERVER as $h=>$v) {
				if(ereg('HTTP_(.+)',$h,$hp))
				$headers[$hp[1]]=$v;
			}
			return $headers;
		}
	}

	protected function _getRequestParams()
	{
		if (count($_POST) > 0) {
			return $_POST;
		}
		$str = file_get_contents('php://input');
		$json = CJSON::decode($str);
		if (is_array($json)) {
			return $json;
		}
		$result=array();
		if(function_exists('mb_parse_str')) {
			mb_parse_str($str, $result);
		} else {
			parse_str($str, $result);
		}
		return $result;
	}
	
	public function actionClientQR()
	{
		$id = Yii::app()->getRequest()->getParam('id', false);
		$client = Client::model()->findByPk($id);
		if ($client) {
			echo CJSON::encode(array('code' => $client->getQRCodeDataUri()));
		} else {
			echo CJSON::encode(array('message' => 'error'));
		}
	}
	
	public function actionTrainerQR()
	{
		$id = Yii::app()->getRequest()->getParam('id', false);
		$trainer = Trainer::model()->findByPk($id);
		if ($trainer) {
			echo CJSON::encode(array('code' => $trainer->getQRCodeDataUri()));
		} else {
			echo CJSON::encode(array('message' => 'error'));
		}
	}
	
	public function actionWorkingHours() {
		$this->_sendResponse(200, array(
			'weekday_open' => Yii::app()->cfg->getItem('weekday_open'),
			'weekday_close' => Yii::app()->cfg->getItem('weekday_close'), 
			'weekend_open' => Yii::app()->cfg->getItem('weekend_open'),
			'weekend_close' => Yii::app()->cfg->getItem('weekend_close'),
		));
	}


	protected function _checkAccess($client_id = null)
	{
		if ($this->current_trainer) return;
		if (!$this->current_client || ($client_id && $client_id != $this->current_client->id)) {
			throw new CHttpException(403,Yii::t('yii','You are not authorized to perform this action.'));
		}
	}
}
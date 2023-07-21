<?php

class TrainerController extends Controller
{

	public $defaultAction = 'admin';
	public $layout = '//layouts/column1';

	/**
	 * @return array action filters
	 */
	public function filters()
	{
		return array(
			'accessControl', // perform access control for CRUD operations
		);
	}

	/**
	 * Specifies the access control rules.
	 * This method is used by the 'accessControl' filter.
	 * @return array access control rules
	 */
	public function accessRules()
	{
		return array(
			array('allow',
				'users' => array('@'),
			),
			array('deny', // deny all users
				'users' => array('*'),
			),
		);
	}

	/**
	 * Creates a new model.
	 * If creation is successful, the browser will be redirected to the 'view' page.
	 */
	public function actionCreate()
	{
		$model	 = new Trainer;
		$oldData = array();

		// Uncomment the following line if AJAX validation is needed
		// $this->performAjaxValidation(ch.esgroup.domainconverter.DomainModel@1b29f80);

		if (isset($_POST['Trainer'])) {
			$model->attributes = $_POST['Trainer'];
			if ($model->save()) {
				$this->redirect(array('admin'));
			}
		}

		$this->render('create', array(
			'model' => $model,
		));
	}

	/**
	 * Updates a particular model.
	 * If update is successful, the browser will be redirected to the 'view' page.
	 * @param integer $id the ID of the model to be updated
	 */
	public function actionUpdate($id)
	{
		$model	 = $this->loadModel($id);
		$oldData = $model->attributes;

		// Uncomment the following line if AJAX validation is needed
		// $this->performAjaxValidation(ch.esgroup.domainconverter.DomainModel@1b29f80);

		if (isset($_POST['Trainer'])) {
			$model->attributes = $_POST['Trainer'];
			if (!isset($_POST['Trainer']['locations'])) {
				$model->locations = array();
			}
			if ($model->save()) {
				$this->redirect(array('admin'));
			}
		}

		$this->render('update', array(
			'model' => $model,
		));
	}

	/**
	 * Deletes a particular model.
	 * If deletion is successful, the browser will be redirected to the 'admin' page.
	 * @param integer $id the ID of the model to be deleted
	 */
	public function actionDelete($id)
	{
		if (Yii::app()->request->isPostRequest) {
			// we only allow deletion via POST request
			$this->loadModel($id)->delete();

			// if AJAX request (triggered by deletion via admin grid view), we should not redirect the browser
			if (!isset($_GET['ajax']))
				$this->redirect(isset($_POST['returnUrl']) ? $_POST['returnUrl'] : array('admin'));
		}
		else
			throw new CHttpException(400, 'Invalid request. Please do not repeat this request again.');
	}

	/**
	 * Manages all models.
	 */
	public function actionAdmin()
	{
		if (isset($_GET['pageSize'])) {
			Yii::app()->user->setState('pageSize', (int) $_GET['pageSize']);
			unset($_GET['pageSize']);
		}

		if (Yii::app()->request->getParam('export')) {
			$this->actionExport();
			Yii::app()->end();
		}

		$model				 = new Trainer('search');
		$model->unsetAttributes();  // clear any default values
		if (isset($_GET['Trainer']))
			$model->attributes	 = $_GET['Trainer'];

		$this->render('admin', array(
			'model' => $model,
		));
	}
	
	public function actionCalendar($id)
	{
		$trainer = $this->loadModel($id);
		
		$baseUrl = Yii::app()->baseUrl;
		$cs = Yii::app()->getClientScript();

		$cs->registerCssFile($cs->getCoreScriptUrl().'/jui/css/base/jquery-ui.css');
		$cs->registerCssFile($baseUrl.'/css/fullcalendar.css');

		$cs->registerCoreScript('jquery');
		$cs->registerCoreScript('yiiactiveform');
		$cs->registerScriptFile($cs->getCoreScriptUrl().'/jui/js/jquery-ui.min.js');
		$cs->registerScriptFile($baseUrl.'/js/fullcalendar.js');
		
		$baseUrlE = Yii::app()->getAssetManager()->publish(Yii::getPathOfAlias('application.extensions.timepicker').'/assets');
		$cs->registerCssFile($baseUrlE.'/jquery-ui-timepicker-addon.css');
		$cs->registerScriptFile($baseUrlE.'/jquery-ui-timepicker-addon.js', CClientScript::POS_END);

		
		$this->render('calendar', array(
			'trainer' => $trainer,
			'view' => isset($_GET['view']) ? $_GET['view'] : 'month',
			'date' => isset($_GET['date']) ? $_GET['date'] : date('Y-m-d'),
		));
	}
	
	public function actionFullCalendar()
	{
		$baseUrl = Yii::app()->baseUrl;
		$cs = Yii::app()->getClientScript();

		$cs->registerCssFile($cs->getCoreScriptUrl().'/jui/css/base/jquery-ui.css');
		$cs->registerCssFile($baseUrl.'/css/fullcalendar.css');

		$cs->registerCoreScript('jquery');
		$cs->registerCoreScript('yiiactiveform');
		$cs->registerScriptFile($cs->getCoreScriptUrl().'/jui/js/jquery-ui.min.js');
		$cs->registerScriptFile($baseUrl.'/js/fullcalendar.js');
		
		$baseUrlE = Yii::app()->getAssetManager()->publish(Yii::getPathOfAlias('application.extensions.timepicker').'/assets');
		$cs->registerCssFile($baseUrlE.'/jquery-ui-timepicker-addon.css');
		$cs->registerScriptFile($baseUrlE.'/jquery-ui-timepicker-addon.js', CClientScript::POS_END);

		
		$this->render('full_calendar', array(
			'view' => isset($_GET['view']) ? $_GET['view'] : 'month',
			'date' => isset($_GET['date']) ? $_GET['date'] : date('Y-m-d'),
		));
	}
	
	public function actionForm($id = false)
	{
		if ($id) {
			$model = TrainerAvailability::model()->findByPk($id);
		} else {
			$model = new TrainerAvailability;
			$model->trainer_id = $_GET['trainer_id'];
		}
		echo $this->renderPartial('_formAvailability', array('model'=>$model, 'view' => $_GET['view']));
		Yii::app()->end();
	}
	
	public function actionListAvailability()
	{
		$condition = null;
		$params = array();
		if ((int)$_GET['start']) {
			$condition = 'date >= :start';
			$params[':start'] = date('Y-m-d', (int)$_GET['start']);
		}
		if ((int)$_GET['end']) {
			if ($condition) {
				$condition .= ' AND ';
			}
			$condition .= 'date <= :end';
			$params[':end'] = date('Y-m-d', (int)$_GET['end']);
		}
		$trainer_ids = Yii::app()->request->getParam('trainer_id');
		if (!is_array($trainer_ids)) {
			$trainer_ids = array($trainer_ids);
		}
		$trainer_ids = array_filter($trainer_ids);
		if (count($trainer_ids) > 0) {
			if ($condition) {
				$condition .= ' AND ';
			}
			$condition .= 'trainer_id in (' . join(',', $trainer_ids) . ')';
		}
		if ($condition) {
			$availabilities = TrainerAvailability::model()->findAll($condition,$params);
		} else {
			$availabilities = TrainerAvailability::model()->findAll();
		}


		$result = array();
		foreach ($availabilities as $availability) {
			$obj = new stdClass();
			$obj->id = $availability->id;
			$obj->title = $availability->trainer->getInitials() . ' ' . $availability->location->name;
			$obj->allDay = false;
			$obj->start = date('Y-m-d', strtotime($availability->date)) . 'T' . $availability->from . ':00Z';
			$obj->end = date('Y-m-d', strtotime($availability->date)) . 'T' . $availability->to . ':00Z';
			$obj->backgroundColor = $availability->trainer->color;
			$obj->borderColor = $availability->trainer->color;
			$obj->details = $availability->getSummary();
			$result[] = $obj;
		}
		echo CJSON::encode($result);
		Yii::app()->end();
	}
	
	public function actionCreateAvaliability()
	{
		$model	 = new TrainerAvailability;
		
		$model->attributes = $_POST['TrainerAvailability'];
		
		if (!$model->save()) {
			Yii::app()->user->setFlash('error', implode('<br/>', $model->getErrors()));
		}
		$this->redirect($this->createUrl('trainer/calendar') . '/'. $model->trainer_id . '?view=agendaDay&date='. $model->date);
	}
	
	public function actionSerialAvalibility($id) {
		$model = new SerialAvalibilityForm();
		$model->trainer_id = $id;
		if (isset($_POST['SerialAvalibilityForm'])) {
			$model->attributes = $_POST['SerialAvalibilityForm'];
			$model->validate();
			if (!$model->hasErrors()) {
				$model->create();
				$this->redirect($this->createUrl('trainer/calendar') . '/'. $model->trainer_id);
			}
		} else {
			$model->rStart = date('d-m-Y');
		}
		$trainer = $this->loadModel($id);
		$this->render('serial', array(
			'model' => $model,
			'trainer' => $trainer,
		));
	}
	
	public function actionUpdateAvaliability($id)
	{
		$model	 = TrainerAvailability::model()->findByPk($id);
		if (!$model) {
			throw new HttpException(404, 'Record not found');
		}
		
		$model->attributes = $_POST['TrainerAvailability'];
		if (!$model->save()) {
			Yii::app()->user->setFlash('error', implode('<br/>', $model->getErrors()));
		}
		$this->redirect($this->createUrl('trainer/calendar') . '/'. $model->trainer_id . '?view=agendaDay&date='. $model->date);
	}
	
	public function actionDeleteAvaliability($id)
	{
		if(Yii::app()->request->isPostRequest)
		{
			$model	 = TrainerAvailability::model()->findByPk($id);
			$model->delete();
		}
		else
			throw new CHttpException(400,'Invalid request. Please do not repeat this request again.');
	}
	
	public function actionMoveAvaliability($id) {
		$dayDelta = (int)$_GET['dayDelta'];
		$minuteDelta = (int)$_GET['minuteDelta'];
		$result = new StdClass();
		$availability = TrainerAvailability::model()->findByPk($id);
		if ($availability) {
			if ($dayDelta) {
				$availability->date = date('Y-m-d', strtotime($dayDelta . 'days', strtotime($availability->date)));
			}
			if ($minuteDelta) {
				$availability->from = date('H:i', strtotime($minuteDelta . 'minutes', strtotime($availability->from)));
				$availability->to = date('H:i', strtotime($minuteDelta . 'minutes', strtotime($availability->to)));
			}
			if (!$availability->save()) {
				$result->error = 'Failed to save changes. Please try later. ';
			}
			$result->data = $availability->getSummary();
		} else {
			$result->error = 'Training not found';
		}
		echo CJSON::encode($result);
		Yii::app()->end();
	}
	
	public function actionCopyAvaliability($id) {
		$dayDelta = (int)$_GET['dayDelta'];
		$minuteDelta = (int)$_GET['minuteDelta'];
		$result = new StdClass();
		$availability = TrainerAvailability::model()->findByPk($id);
		if ($availability) {
			$availiabilityCopy = new TrainerAvailability();
			if ($dayDelta) {
				$availiabilityCopy->date = date('Y-m-d', strtotime($dayDelta . 'days', strtotime($availability->date)));
			} else {
				$availiabilityCopy->date = $availability->date;
			}
			
			if ($minuteDelta) {
				$availiabilityCopy->from = date('H:i', strtotime($minuteDelta . 'minutes', strtotime($availability->from)));
				$availiabilityCopy->to = date('H:i', strtotime($minuteDelta . 'minutes', strtotime($availability->to)));
			} else {
				$availiabilityCopy->from = $availability->from;
				$availiabilityCopy->to = $availability->to;
			}
			
			$availiabilityCopy->trainer_id = $availability->trainer_id;
			$availiabilityCopy->location_id = $availability->location_id;
			$availiabilityCopy->training_type_id = $availability->training_type_id;
			
			if (!$availiabilityCopy->save()) {
				$result->error = 'Failed to save changes. Please try later. ';
			}
			$result->id = $availiabilityCopy->id;
			$result->data = $availiabilityCopy->getSummary();
		} else {
			$result->error = 'Avalibility not found';
		}
		echo CJSON::encode($result);
		Yii::app()->end();
	}
	
	public function actionResizeAvaliability($id) {
		$minuteDelta = (int)$_GET['minuteDelta'];
		$result = new StdClass();
		$availability = TrainerAvailability::model()->findByPk($id);
		if ($availability) {
			if ($minuteDelta) {
				$availability->to = date('H:i', strtotime($minuteDelta . 'minutes', strtotime($availability->to)));
			}
			if (!$availability->save()) {
				$result->error = 'Failed to save changes. Please try later. ';
			}
			$result->data = $availability->getSummary();
		} else {
			$result->error = 'Training not found';
		}
		echo CJSON::encode($result);
		Yii::app()->end();
	}
	

	/**
	 * Returns the data model based on the primary key given in the GET variable.
	 * If the data model is not found, an HTTP exception will be raised.
	 * @param integer the ID of the model to be loaded
	 */
	public function loadModel($id)
	{
		$model = Trainer::model()->findByPk($id);
		if ($model === null)
			throw new CHttpException(404, 'The requested page does not exist.');
		return $model;
	}

	public function getModel()
	{
		return Trainer::model();
	}

	/**
	 * Performs the AJAX validation.
	 * @param CModel the model to be validated
	 */
	protected function performAjaxValidation($model)
	{
		if (isset($_POST['ajax']) && ($_POST['ajax'] === 'trainer-form' || $_POST['ajax'] === 'trainerav-form')) {
			echo CActiveForm::validate($model);
			Yii::app()->end();
		}
	}

	public function gridActionColumn($data, $row)
	{
		$list = array('update' => 'Edit', 'delete' => 'Delete', 'calendar' => 'Availability calendar', 'qrcode' => 'Get QR code');
		return CHtml::dropDownList('actions', '', $list, array('empty'		 => '(Action)', 'onchange'	 => 'js:processAction($(this).val(), ' . $data->id . ');')
		);
	}

	public function gridActiveColumn($data, $row)
	{
		if ($data->active) {
			return 'x';
		} else {
			return '';
		}
	}

	public function gridPublishedColumn($data, $row)
	{
		if ($data->published) {
			return 'x';
		} else {
			return '';
		}
	}
	
	public function gridColorColumn($data, $row) {
		return '<span style="background:' . $data->color . ';" class="color-preview">&nbsp;</span>';
	}

	public function actionExport()
	{
		$fp		 = fopen('php://temp', 'w');
		$headers = array(
			'id',
			'surname',
			'name',
			'e_mail',
			'phone',
			'mobile',
			'foto',
			array(
				'name'	 => 'active',
				'value'	 => array($this, 'gridActiveColumn'),
				'filter' => CHtml::listData(
						array(
					array('id'	 => '1', 'title'	 => 'Active'),
					array('id'	 => '0', 'title'	 => 'Not Active'),
						), 'id', 'title'),
			),
			array(
				'name'	 => 'published',
				'value'	 => array($this, 'gridPublishedColumn'),
				'filter' => CHtml::listData(
						array(
					array('id'	 => '1', 'title'	 => 'Published'),
					array('id'	 => '0', 'title'	 => 'Not Published'),
						), 'id', 'title'),
			),
		);

		$row = array();
		foreach ($headers as $header) {
			if (is_array($header)) {
				$row[] = $this->getModel()->getAttributeLabel($header['name']);
			} else {
				$row[] = $this->getModel()->getAttributeLabel($header);
			}
		}
		fputcsv($fp, $row);

		$model = new Trainer('search');
		$model->unsetAttributes();  // clear any default values
		if (isset($_GET['Trainer'])) {
			$model->attributes	 = $_GET['Trainer'];
		}
		$provider			 = $model->search();

		foreach ($provider->getData() as $model) {
			$row = array();
			foreach ($headers as $header) {
				if (is_array($header)) {
					if (isset($header['value'])) {
						$row[] = $this->evaluateExpression($header['value'], array('data' => $model));
					} else {
						$row[] = CHtml::value($model, $header['name']);
					}
				} else {
					$row[] = CHtml::value($model, $header);
				}
			}
			fputcsv($fp, $row);
		}
		rewind($fp);
		Yii::app()->user->setState('export', stream_get_contents($fp));
		fclose($fp);
	}

	public function actionExportFile()
	{
		Yii::app()->request->sendFile('Trainer.csv', Yii::app()->user->getState('export'));
		Yii::app()->user->clearState('export');
	}

	
	public function actionQrcode($id)
	{
		$trainer = $this->loadModel($id);
		Header("Content-type: image/png");
		$trainer->getQRCodeImage();
	}
}
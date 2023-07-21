<?php

return array(
	'basePath'=>dirname(__FILE__).DIRECTORY_SEPARATOR.'..',
	'name'=>'Sihl Training',

	// preloading 'log' component
	'preload'=>array('log'),

	// autoloading model and component classes
	'import'=>array(
		'application.models.*',
		'application.components.*',
		'ext.yii-mail.YiiMailMessage',		
	),

	// application components
	'components'=>array(
		'user'=>array(
			// enable cookie-based authentication
			'allowAutoLogin'=>true,
		),
		'urlManager'=>array(
			'urlFormat'=>'path',
			'showScriptName'=>false,
			'rules'=>array(
				array('api/recording', 'pattern'=>'api/recording'),
				array('api/settings', 'pattern'=>'api/settings'),
				array('api/saveRecording', 'pattern'=>'api/saveRecording'),
				array('api/generateChart', 'pattern'=>'api/generateChart'),
				array('api/saveRatesAndBelt', 'pattern'=>'api/saveRatesAndBelt'),
				array('api/saveSerialAvalibility', 'pattern'=>'api/saveSerialAvalibility'),
				array('api/changePassword', 'pattern'=>'api/changePassword'),
				array('api/saveRunning', 'pattern'=>'api/saveRunning'),
				array('api/saveIntervalSettings', 'pattern'=>'api/saveIntervalSettings'),
				array('api/feedback', 'pattern'=>'api/feedback', 'verb'=>'GET'),
				array('api/saveFeedback', 'pattern'=>'api/feedback', 'verb'=>'POST'),
				array('api/markClientFeedback', 'pattern'=>'api/markClientFeedback', 'verb'=>'POST'),
				array('api/markTrainerFeedback', 'pattern'=>'api/markTrainerFeedback', 'verb'=>'POST'),
				array('api/getIcal', 'pattern'=>'api/getIcal'),
				array('api/token', 'pattern'=>'api/token'),
				array('api/loginTrainer', 'pattern'=>'api/loginTrainer'),
				array('api/avaliability', 'pattern'=>'api/avaliability'),
				array('api/fullAvaliability', 'pattern'=>'api/fullAvaliability'),
				array('api/cancelTraining', 'pattern'=>'api/cancelTraining'),
				array('api/cancelTrainingTrainer', 'pattern'=>'api/cancelTrainingTrainer'),
				array('api/nextTrainerAppointment', 'pattern'=>'api/nextTrainerAppointment'),
				array('api/inviteTraining', 'pattern'=>'api/inviteTraining'),
				array('api/inviteTrainingTrainer', 'pattern'=>'api/inviteTrainingTrainer'),
				array('api/sendFile', 'pattern'=>'api/sendFile'),
				array('api/sendPlan', 'pattern'=>'api/sendPlan'),
				array('api/sendAnamnese', 'pattern'=>'api/sendAnamnese'),
				array('api/clientQR', 'pattern'=>'api/clientQR'),
				array('api/trainerQR', 'pattern'=>'api/trainerQR'),
				array('api/credits', 'pattern'=>'api/credits'),
				array('api/totalCredits', 'pattern'=>'api/totalCredits'),
				array('api/workingHours', 'pattern'=>'api/workingHours'),
				array('api/resources', 'pattern' => 'api/resources', 'urlSuffix'=>'.json'),
				array('api/models', 'pattern'=>'api/models', 'verb'=>'GET'),
				array('api/serviceList', 'pattern'=>'api/serviceList', 'verb'=>'GET'),
				array('api/view', 'pattern'=>'api/<model:\w+>/<id:\d+>', 'verb'=>'GET'),
				array('api/service', 'pattern'=>'api/<model:\w+>/<service:\w+>', 'verb'=>'GET'),
				array('api/list', 'pattern'=>'api/<model:\w+>', 'verb'=>'GET'),
				array('api/update', 'pattern'=>'api/<model:\w+>/<id:\d+>', 'verb'=>'PUT'),
				array('api/delete', 'pattern'=>'api/<model:\w+>/<id:\d+>', 'verb'=>'DELETE'),
				array('api/create', 'pattern'=>'api/<model:\w+>', 'verb'=>'POST'),
				array('api/doc', 'pattern' => 'api/<model:\w+>', 'urlSuffix'=>'.json'),
				'elfinder/getEncrypted/<file:.*?>' => 'elfinder/getEncrypted',
				'<controller:\w+>/<id:\d+>'=>'<controller>/view',
				'<controller:\w+>/<action:\w+>/<id:\d+>'=>'<controller>/<action>',
				'<controller:\w+>/<action:\w+>'=>'<controller>/<action>',
			),
		),
		'db'=>array(
			'connectionString' => 'mysql:host=sihltrai.mysql.db.internal;dbname=sihltrai_admin',
			'emulatePrepare' => true,
			'username' => 'sihltrai_admin',
			'password' => '$p0rTW0Rd',
			'tablePrefix' => 'tbl_',
			'charset' => 'utf8',
			'enableParamLogging' => true,
		),
		'errorHandler'=>array(
			// use 'site/error' action to display errors
            'errorAction'=>'site/error',
        ),
		'log'=>array(
			'class'=>'CLogRouter',
			'routes'=>array(
				array(
					'class'=>'CFileLogRoute',
					'levels'=>'error, warning, info',
				),
				// uncomment the following to show log messages on web pages
				/*
				array(
					'class'=>'CWebLogRoute',
				),
				*/
			),
		),
		'mail' => array(
 			'class' => 'ext.yii-mail.YiiMail',
 			'transportType' => 'php',
 			'viewPath' => 'application.views.mail',
 			'logging' => true,
 			'dryRun' => false
 		),
		'CURL' =>array(
			'class' => 'application.extensions.curl.Curl',
			'options' => array(
				'setOptions' => array(
					CURLOPT_SSL_VERIFYPEER => false,
					CURLOPT_FOLLOWLOCATION => false,
				),
			),
		),
		'cfg'=>array(
            'class' =>  'application.components.MyConfig',
            'useCache'=>false,
            'tableName'=>'{{settings}}',
            'loadDbItems'=>true,
            'serializeValues'=>true,
        ),
		'ePdf' => array(
			'class'         => 'ext.yii-pdf.EYiiPdf',
			'params'        => array(
				'HTML2PDF' => array(
					'librarySourcePath' => 'application.vendors.html2pdf.*',
					'classFile'         => 'html2pdf.class.php',
					'defaultParams'     => array( // More info: http://wiki.spipu.net/doku.php?id=html2pdf:en:v4:accueil
						'orientation' => 'L', // landscape or portrait orientation
						'format'      => 'A4', // format A4, A5, ...
						'language'    => 'de', // language: fr, en, it ...
						'unicode'     => true, // TRUE means clustering the input text IS unicode (default = true)
						'encoding'    => 'UTF-8', // charset encoding; Default is UTF-8
						'marges'      => array(5, 5, 5, 8), // margins by default, in order (left, top, right, bottom)
					),
				),
			),
		),
	),

	// application-level parameters that can be accessed
	// using Yii::app()->params['paramName']
	'params'=>array(
		'defaultPageSize'=>10,
		'adminEmail' => 'hello@sihltraining.ch'
	),
);
<?php

return array(
	'basePath'=>dirname(__FILE__).DIRECTORY_SEPARATOR.'..',
	'name'=>'Sport clinic local',

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
					'levels'=>'error,warning,info',
					'logFile'=>'cron.log',
				),
				// uncomment the following to show log messages on web pages
				
//				array(
//					'class'=>'CWebLogRoute',
//				),
				
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
					CURLOPT_SSL_VERIFYPEER => false
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
		'adminEmail' => 'sportclinic@esgservices.ch'
	),
);
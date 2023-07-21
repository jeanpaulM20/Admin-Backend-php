<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
<head>
	<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
	<meta name="language" content="en" />

	<!-- blueprint CSS framework -->
	<link rel="stylesheet" type="text/css" href="<?php echo Yii::app()->request->baseUrl; ?>/css/screen.css" media="screen, projection" />
	<link rel="stylesheet" type="text/css" href="<?php echo Yii::app()->request->baseUrl; ?>/css/print.css" media="print" />
	<!--[if lt IE 8]>
	<link rel="stylesheet" type="text/css" href="<?php echo Yii::app()->request->baseUrl; ?>/css/ie.css" media="screen, projection" />
	<![endif]-->

	<link rel="stylesheet" type="text/css" href="<?php echo Yii::app()->request->baseUrl; ?>/css/main.css" />
	<link rel="stylesheet" type="text/css" href="<?php echo Yii::app()->request->baseUrl; ?>/css/form.css" />

	<title><?php echo CHtml::encode($this->pageTitle); ?></title>
</head>

<body>

<div class="container" id="page">

	<div id="header">
		<div id="logo"><?php echo CHtml::encode(Yii::app()->name); ?></div>
	</div><!-- header -->

	<div id="mainmenu">
		<?php $this->widget('zii.widgets.CMenu',array(
			'activateParents' => true,
			'items'=>array(
				array('label'=>'Home', 'url'=>array('/site/index')),
				array(
					'label'=>'Trainer', 
					'url'=>array('/trainer/admin'), 
					'visible'=>!Yii::app()->user->isGuest,
					'items' => array(
						array('label'=>'Calender', 'url'=>array('/trainer/fullCalendar'), 'visible'=>!Yii::app()->user->isGuest),
					)
				),
				array(
					'label'=>'Client', 
					'url'=>array('/client/admin'), 
					'visible'=>!Yii::app()->user->isGuest,
					'items' => array(
						array('label'=>'Account', 'url'=>array('/account/admin'), 'visible'=>!Yii::app()->user->isGuest, 'tag' => 'account'),
						array('label'=>'Preference', 'url'=>array('/preference/admin'), 'visible'=>!Yii::app()->user->isGuest),
						array('label'=>'Credits', 'url'=>array('/credits/admin'), 'visible'=>!Yii::app()->user->isGuest),
						array('label'=>'File', 'url'=>array('/file/admin'), 'visible'=>!Yii::app()->user->isGuest),
						array('label'=>'Metric', 'url'=>array('/metric/admin'), 'visible'=>!Yii::app()->user->isGuest),
						array('label'=>'Trainingplan', 'url'=>array('/trainingplan/admin'), 'visible'=>!Yii::app()->user->isGuest),
						array('label'=>'Performance Tests', 'url'=>array('/performance/admin'), 'visible'=>!Yii::app()->user->isGuest),
						array('label'=>'Feedback chat', 'url'=>array('/client/feedback'), 'visible'=>!Yii::app()->user->isGuest),
					)
				),
				
				array('label'=>'Training', 'url'=>array('/training/admin'), 'visible'=>!Yii::app()->user->isGuest),
				array(
					'label'=>'Review', 
					'url'=>array('/review/admin'), 
					'visible'=>!Yii::app()->user->isGuest,
					'items' => array(
						array('label'=>'Review Offsite', 'url'=>array('/review/offsite'), 'visible'=>!Yii::app()->user->isGuest),
					)
				),
				array(
					'label'=>'Sihltraining', 
					'url' => '#',
					'visible'=>!Yii::app()->user->isGuest,
					'items' => array(
						array('label'=>'Location', 'url'=>array('/location/admin'), 'visible'=>!Yii::app()->user->isGuest),
						array('label'=>'Content', 'url'=>array('/content/admin'), 'visible'=>!Yii::app()->user->isGuest),
						array('label'=>'Offer', 'url'=>array('/offer/admin'), 'visible'=>!Yii::app()->user->isGuest),
						array('label'=>'Lockers', 'url'=>array('/locker/admin'), 'visible'=>!Yii::app()->user->isGuest),
					)
				),
				array(
					'label'=>'Site', 
					'url' => '#',
					'visible'=>!Yii::app()->user->isGuest,
					'items' => array(
						array('label'=>'Language', 'url'=>array('/language/admin'), 'visible'=>!Yii::app()->user->isGuest),
						array('label'=>'Translation', 'url'=>array('/translation/admin'), 'visible'=>!Yii::app()->user->isGuest),
						array('label'=>'Settings', 'url'=>array('/settings/admin'), 'visible'=>!Yii::app()->user->isGuest),
						array('label'=>'API services', 'url'=>array('/service/admin'), 'visible'=>!Yii::app()->user->isGuest),
					)
				),
				array(
					'label' => 'Logs',
					'url' => '#',
					'visible'=>!Yii::app()->user->isGuest,
					'items' => array(
						array('label'=>'Door Log', 'url'=>array('/door/admin'), 'visible'=>!Yii::app()->user->isGuest),
						array('label'=>'Screen statistics', 'url'=>array('/screenstats/admin'), 'visible'=>!Yii::app()->user->isGuest),
					)
				),
				
				//array('label'=>'Goal', 'url'=>array('/goal/admin'), 'visible'=>!Yii::app()->user->isGuest),
				//array('label'=>'ExerciseSet', 'url'=>array('/exerciseset/admin'), 'visible'=>!Yii::app()->user->isGuest),
				//array('label'=>'Exercise', 'url'=>array('/exercise/admin'), 'visible'=>!Yii::app()->user->isGuest),
				//array('label'=>'Exercise group', 'url'=>array('/exercisegroup/admin'), 'visible'=>!Yii::app()->user->isGuest),
				//array('label'=>'Exercise subgroup', 'url'=>array('/exercisesubgroup/admin'), 'visible'=>!Yii::app()->user->isGuest),
				//array('label'=>'API docs', 'url'=>array('/apidocs')),
				array('label'=>'Login', 'url'=>array('/site/login'), 'visible'=>Yii::app()->user->isGuest),
				array('label'=>'Logout ('.Yii::app()->user->name.')', 'url'=>array('/site/logout'), 'visible'=>!Yii::app()->user->isGuest)
			),
		)); ?>
	</div><!-- mainmenu -->
	<?php if(isset($this->breadcrumbs)):?>
		<?php $this->widget('zii.widgets.CBreadcrumbs', array(
			'links'=>$this->breadcrumbs,
		)); ?><!-- breadcrumbs -->
	<?php endif?>

	<?php echo $content; ?>

	<div class="clear"></div>

	<div id="footer">
		<?php echo Yii::powered(); ?>
	</div><!-- footer -->

</div><!-- page -->

</body>
</html>
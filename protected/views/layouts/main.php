<!DOCTYPE html>
<html lang="en">
<head>
	<meta charset="utf-8">
	<meta name="viewport" content="width=device-width, initial-scale=1">
	<meta name="language" content="en">

	<!-- Bootstrap 5 -->
	<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css">
	<!-- Bootstrap Icons -->
	<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.3/font/bootstrap-icons.min.css">

	<link rel="stylesheet" type="text/css" href="<?php echo Yii::app()->request->baseUrl; ?>/css/bootstrap-overrides.css" />
	<link rel="stylesheet" type="text/css" href="<?php echo Yii::app()->request->baseUrl; ?>/css/main.css" />
	<link rel="stylesheet" type="text/css" href="<?php echo Yii::app()->request->baseUrl; ?>/css/form.css" />

	<title><?php echo CHtml::encode($this->pageTitle); ?></title>
</head>

<body>

<div id="page">

	<nav class="navbar navbar-expand-lg" id="mainmenu">
		<div class="container-fluid px-3">
			<a class="navbar-brand" href="<?php echo Yii::app()->createUrl('/site/index'); ?>">
				<i class="bi bi-activity me-1"></i><?php echo CHtml::encode(Yii::app()->name); ?>
			</a>
			<button class="navbar-toggler" type="button" data-bs-toggle="collapse" data-bs-target="#navbarMain" aria-controls="navbarMain" aria-expanded="false">
				<span class="navbar-toggler-icon"></span>
			</button>
			<div class="collapse navbar-collapse" id="navbarMain">
				<?php $this->widget('zii.widgets.CMenu', array(
					'htmlOptions' => array('class' => 'navbar-nav me-auto mb-2 mb-lg-0'),
					'activateParents' => true,
					'encodeLabel' => false,
					'items' => array(
						array('label' => '<i class="bi bi-house-door"></i> Home', 'url' => array('/site/index')),
						array(
							'label' => '<i class="bi bi-person-badge"></i> Trainer',
							'url' => array('/trainer/admin'),
							'visible' => !Yii::app()->user->isGuest,
							'items' => array(
								array('label' => '<i class="bi bi-calendar3"></i> Calendar', 'url' => array('/trainer/fullCalendar'), 'visible' => !Yii::app()->user->isGuest),
							)
						),
						array(
							'label' => '<i class="bi bi-people"></i> Client',
							'url' => array('/client/admin'),
							'visible' => !Yii::app()->user->isGuest,
							'items' => array(
								array('label' => '<i class="bi bi-person-circle"></i> Account', 'url' => array('/account/admin'), 'visible' => !Yii::app()->user->isGuest),
								array('label' => '<i class="bi bi-sliders"></i> Preference', 'url' => array('/preference/admin'), 'visible' => !Yii::app()->user->isGuest),
								array('label' => '<i class="bi bi-coin"></i> Credits', 'url' => array('/credits/admin'), 'visible' => !Yii::app()->user->isGuest),
								array('label' => '<i class="bi bi-file-earmark"></i> File', 'url' => array('/file/admin'), 'visible' => !Yii::app()->user->isGuest),
								array('label' => '<i class="bi bi-graph-up"></i> Metric', 'url' => array('/metric/admin'), 'visible' => !Yii::app()->user->isGuest),
								array('label' => '<i class="bi bi-journal-text"></i> Trainingplan', 'url' => array('/trainingplan/admin'), 'visible' => !Yii::app()->user->isGuest),
								array('label' => '<i class="bi bi-speedometer2"></i> Performance Tests', 'url' => array('/performance/admin'), 'visible' => !Yii::app()->user->isGuest),
								array('label' => '<i class="bi bi-chat-dots"></i> Feedback chat', 'url' => array('/client/feedback'), 'visible' => !Yii::app()->user->isGuest),
							)
						),
						array('label' => '<i class="bi bi-calendar-check"></i> Training', 'url' => array('/training/admin'), 'visible' => !Yii::app()->user->isGuest),
						array(
							'label' => '<i class="bi bi-star"></i> Review',
							'url' => array('/review/admin'),
							'visible' => !Yii::app()->user->isGuest,
							'items' => array(
								array('label' => '<i class="bi bi-star-half"></i> Review Offsite', 'url' => array('/review/offsite'), 'visible' => !Yii::app()->user->isGuest),
							)
						),
						array(
							'label' => '<i class="bi bi-building"></i> Sihltraining',
							'url' => '#',
							'visible' => !Yii::app()->user->isGuest,
							'items' => array(
								array('label' => '<i class="bi bi-geo-alt"></i> Location', 'url' => array('/location/admin'), 'visible' => !Yii::app()->user->isGuest),
								array('label' => '<i class="bi bi-file-text"></i> Content', 'url' => array('/content/admin'), 'visible' => !Yii::app()->user->isGuest),
								array('label' => '<i class="bi bi-tag"></i> Offer', 'url' => array('/offer/admin'), 'visible' => !Yii::app()->user->isGuest),
								array('label' => '<i class="bi bi-lock"></i> Lockers', 'url' => array('/locker/admin'), 'visible' => !Yii::app()->user->isGuest),
							)
						),
						array(
							'label' => '<i class="bi bi-gear"></i> Site',
							'url' => '#',
							'visible' => !Yii::app()->user->isGuest,
							'items' => array(
								array('label' => '<i class="bi bi-translate"></i> Language', 'url' => array('/language/admin'), 'visible' => !Yii::app()->user->isGuest),
								array('label' => '<i class="bi bi-fonts"></i> Translation', 'url' => array('/translation/admin'), 'visible' => !Yii::app()->user->isGuest),
								array('label' => '<i class="bi bi-sliders2"></i> Settings', 'url' => array('/settings/admin'), 'visible' => !Yii::app()->user->isGuest),
								array('label' => '<i class="bi bi-plug"></i> API services', 'url' => array('/service/admin'), 'visible' => !Yii::app()->user->isGuest),
							)
						),
						array(
							'label' => '<i class="bi bi-journal-code"></i> Logs',
							'url' => '#',
							'visible' => !Yii::app()->user->isGuest,
							'items' => array(
								array('label' => '<i class="bi bi-door-open"></i> Door Log', 'url' => array('/door/admin'), 'visible' => !Yii::app()->user->isGuest),
								array('label' => '<i class="bi bi-display"></i> Screen statistics', 'url' => array('/screenstats/admin'), 'visible' => !Yii::app()->user->isGuest),
							)
						),
						array('label' => '<i class="bi bi-box-arrow-in-right"></i> Login', 'url' => array('/site/login'), 'visible' => Yii::app()->user->isGuest),
						array('label' => '<i class="bi bi-box-arrow-right"></i> Logout (' . Yii::app()->user->name . ')', 'url' => array('/site/logout'), 'visible' => !Yii::app()->user->isGuest),
					),
				)); ?>
			</div>
		</div>
	</nav>

	<?php if (isset($this->breadcrumbs)): ?>
	<nav aria-label="breadcrumb" class="breadcrumb-nav">
		<div class="container-fluid px-3">
			<?php $this->widget('zii.widgets.CBreadcrumbs', array(
				'links' => $this->breadcrumbs,
			)); ?>
		</div>
	</nav>
	<?php endif; ?>

	<main class="container-fluid px-3 py-3" id="main-content">
		<?php echo $content; ?>
	</main>

	<footer id="footer">
		<?php echo Yii::powered(); ?>
	</footer>

</div><!-- page -->

<!-- Bootstrap 5 JS -->
<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"></script>
</body>
</html>

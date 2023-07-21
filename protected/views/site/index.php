<?php $this->pageTitle=Yii::app()->name; ?>

<h1>Welcome to <i><?php echo CHtml::encode(Yii::app()->name); ?></i></h1>

<?php if (!Yii::app()->user->isGuest): ?>
	<h4>Api endpoints</h4>
	<ul>
		<li><?php echo $this->createAbsoluteUrl('api/trainer') ?></li>
		<li><?php echo $this->createAbsoluteUrl('api/client') ?></li>
		<li><?php echo $this->createAbsoluteUrl('api/client_access_token') ?></li>
		<li><?php echo $this->createAbsoluteUrl('api/account') ?></li>
		<li><?php echo $this->createAbsoluteUrl('api/location') ?></li>
		<!--<li><?php echo $this->createAbsoluteUrl('api/goal') ?></li>-->
		<li><?php echo $this->createAbsoluteUrl('api/metric') ?></li>
		<li><?php echo $this->createAbsoluteUrl('api/training') ?></li>
		<li><?php echo $this->createAbsoluteUrl('api/exerciseset') ?></li>
		<li><?php echo $this->createAbsoluteUrl('api/review') ?></li>
		<li><?php echo $this->createAbsoluteUrl('api/review_heart_rate_timeseries') ?></li>
		<li><?php echo $this->createAbsoluteUrl('api/exercise') ?></li>
		<li><?php echo $this->createAbsoluteUrl('api/exercise_pictures') ?></li>
		<li><?php echo $this->createAbsoluteUrl('api/content') ?></li>
		<li><?php echo $this->createAbsoluteUrl('api/offer') ?></li>
		<li><?php echo $this->createAbsoluteUrl('api/preference') ?></li>
		<li><?php echo $this->createAbsoluteUrl('api/language') ?></li>
		<li><?php echo $this->createAbsoluteUrl('api/file') ?></li>
		<li><?php echo $this->createAbsoluteUrl('api/translation') ?></li>
	</ul>
<?php endif; ?>
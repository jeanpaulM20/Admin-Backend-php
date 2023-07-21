<style>
	.anamnese-table {width: 100%; border-collapse: collapse; }
	.anamnese-table td {width: 50%; border: 1px solid #000;padding: 10px;  }
	.anamnese-table th {background: #000; color: #fff; text-align: center; border: 1px solid #000; padding: 10px; }
	.anamnese-table textarea,  .anamnese-table input[type=text] {width: 100%; border-width: 0 0 1px 0; border-color: #000; }
	.anamnese-table ul {list-style-type: none; margin: 0;}
	.anamnese-table ul.labels li {height: 23px;}
	.anamnese-table ul.inputs li {height: 23px;}
	.anamnese-table .separator {display: inline-block; width: 33%;}
</style>
<h3 style="text-align: center;width:100%;">Anamnesefragebogen</h3>
<table class="anamnese-table">
    <tr>
        <th colspan="2">Fragen zur beruflichen Situation</th>
    </tr>
    <tr>
        <td>Name, Vorname</td>
        <td><?php echo $anamnese->client->surname . ' ' . $anamnese->client->name ?></td>
    </tr>
    <tr>
        <td>Geburtsdatum</td>
        <td><?php echo $anamnese->client->birthday ?></td>
    </tr>
    <tr>
        <td>Tel.</td>
        <td><?php echo $anamnese->client->phone ?></td>
    </tr>
    <tr>
        <td>Email</td>
        <td><?php echo $anamnese->client->e_mail ?></td>
    </tr>
    <tr>
        <td>Anschrift</td>
        <td><?php echo $anamnese->address ?></td>
    </tr>
    <tr>
        <td>Was für einen Beruf führen Sie aktuell aus?</td>
        <td><?php echo $anamnese->profession ?></td>
    </tr>
    <tr>
        <td>Welche Tätigkeiten beinhaltet ihre Arbeit hauptsächlich?</td>
        <td>
			<?php foreach ($anamnese->getActivitiesList() as $key => $value): ?>
				<img src="<?php echo Yii::getPathOfAlias('application.runtime')  . DIRECTORY_SEPARATOR . ($anamnese->activities == $key ? 'check_box_active.png' : 'check_box.png');?>">
				<?php echo $value ?><br/>
			<?php endforeach; ?>
		</td>
    </tr>
    <tr>
        <th colspan="2">Fragen zu körperlicher Aktivität in der Freizeit</th>
    </tr>
    <tr>
        <td>Wie sieht Ihre körperliche Beanspruchung in der Freizeit oder auf dem Arbeitsweg aus?</td>
		<td>
			<?php foreach ($anamnese->getPhysicalDemandsList() as $key => $value): ?>
				<img src="<?php echo Yii::getPathOfAlias('application.runtime')  . DIRECTORY_SEPARATOR . ($anamnese->physical_demands == $key ? 'check_box_active.png' : 'check_box.png');?>">
				<?php echo $value ?><br/>
			<?php endforeach; ?>
		</td>
    </tr>
    <tr>
        <th colspan="2">Fragen zur sportlichen Aktivität und Regenerationsmassnahmen</th>
    </tr>
    <tr>
        <td>Welche Sportarten betreiben Sie regelmässig?</td>
        <td><?php echo $anamnese->sportarts ?></td>
    </tr>
    <tr>
        <td>In welchem Umfang betreiben Sie die erwähnten Sportarten? (Anzahl Stunden pro Woche)</td>
        <td><?php echo $anamnese->sportarts_scope ?></td>
    </tr>
    <tr>
        <td>In welcher Intensität betreiben sie die erwähnten Sportarten?</td>
		<td>
			<?php foreach ($anamnese->getSportartsIntencityList() as $key => $value): ?>
				<img src="<?php echo Yii::getPathOfAlias('application.runtime')  . DIRECTORY_SEPARATOR . ($anamnese->sportarts_intencity == $key ? 'check_box_active.png' : 'check_box.png');?>">
				<?php echo $value ?><br/>
			<?php endforeach; ?>
		</td>
    </tr>
    <tr>
        <td>Wieviele Stunden schlafen sie normalerweise  pro Nacht?</td>
        <td>
			Unter der Woche:<br/>
			<div style="width:100%; border-bottom: 1px solid #000;"><?php echo $anamnese->sleep_week ?></div><br/>
			Am Wochenende:<br/>
			<div style="width:100%; border-bottom: 1px solid #000;"><?php echo $anamnese->sleep_weekend ?></div><br/>
		</td>
    </tr>
    <tr>
        <td>Wieviele Stunden Entspannung gönnen Sie sich pro Tag?</td>
        <td>
			Unter der Woche:<br/>
			<div style="width:100%; border-bottom: 1px solid #000;"><?php echo $anamnese->relaxation_week ?></div><br/>
			Am Wochenende:<br/>
			<div style="width:100%; border-bottom: 1px solid #000;"><?php echo $anamnese->relaxation_weekend ?></div><br/>
		</td>
    </tr>
    <tr>
        <td>Wieviele trainingsfreie Tage pro Woche haben Sie?</td>
        <td><?php echo $anamnese->training_dayoff ?></td>
    </tr>
    <tr>
        <th colspan="2">Fragen zum Aktuellen Gesundheitsstand</th>
    </tr>
	<tr>
		<td>Sind sie zur Zeit in ärztlicher Behandlung?</td>
		<td>
			<?php foreach ($anamnese->getYesNoList() as $key => $value): ?>
				<img src="<?php echo Yii::getPathOfAlias('application.runtime')  . DIRECTORY_SEPARATOR . ($anamnese->medical_treatment == $key ? 'check_box_active.png' : 'check_box.png');?>">
				<?php echo $value ?>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
			<?php endforeach; ?>
		</td>
	</tr>
	<tr>
		<td>Nehmen Sie regelmässig Medikmente?</td>
		<td>
			<?php foreach ($anamnese->getYesNoList() as $key => $value): ?>
				<img src="<?php echo Yii::getPathOfAlias('application.runtime')  . DIRECTORY_SEPARATOR . ($anamnese->taking_drugs == $key ? 'check_box_active.png' : 'check_box.png');?>">
				<?php echo $value ?>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
			<?php endforeach; ?>
		</td>
	</tr>
    <tr>
        <td>
			Leiden Sie zurzeit an einer Verletzung?<br/>
			<br/><br/>
			<i>Falls ja:</i><br/>
			<ul class="labels">
				<li>Art der Verletzung?</li>
				<li>Verletzter Körperteil?</li>
				<li>Handelt es sich um eine chronische Verletzung?</li>
			</ul>
		</td>
        <td>
			<?php foreach ($anamnese->getYesNoList() as $key => $value): ?>
				<img src="<?php echo Yii::getPathOfAlias('application.runtime')  . DIRECTORY_SEPARATOR . ($anamnese->injury == $key ? 'check_box_active.png' : 'check_box.png');?>">
				<?php echo $value ?><br/>
			<?php endforeach; ?>
			<br/>
			<ul class="inputs">
				<li><div style="width:100%; border-bottom: 1px solid #000;"><?php echo $anamnese->injury_type ?></div></li>
				<li><div style="width:100%; border-bottom: 1px solid #000;"><?php echo $anamnese->injury_bodypart ?></div></li>
				<li>
					<?php foreach ($anamnese->getYesNoList() as $key => $value): ?>
						<img src="<?php echo Yii::getPathOfAlias('application.runtime')  . DIRECTORY_SEPARATOR . ($anamnese->injury_chronic == $key ? 'check_box_active.png' : 'check_box.png');?>">
						<?php echo $value ?><br/>
					<?php endforeach; ?>
				</li>
			</ul>
		</td>
    </tr>
    <tr>
        <td style="vertical-align: top;">
			Leiden Sie an einer der folgenden Krankheiten?<br/><br/>
			<ul class="labels">
				<li>Herzinfarkt (&lt;0.5 Jahre)</li>
				<li>Arterielle Durchblutungsstörungen (Stadien III/IV)</li>
				<li>Raynauld Syndrom</li>
				<li>Vaskulitis</li>
				<li>Erkrankungen mit erhöhter Kälteempfinden</li>
				<li>Sensibilitätsstörungen</li>
				<li>Durchblutungsstörungen</li>
				<li>Nervenschädigung</li>
				<li>Replantation</li>
				<li>Schädigung peripherer Lymphgefässe</li>
				<li>Kältehämoglobinämie, -agglutin Krankheit, Kryogloulinämie</li>
				<li>Nieren- und Blasenaffektionen</li>
				<li>Schwere Herz- & Kreislauferkrankungen</li>
			</ul>
		</td>
        <td style="vertical-align: top;">
			<br/><br/>
			<ul class="inputs">
				<li>
					<?php foreach ($anamnese->getYesNoList() as $key => $value): ?>
						<img src="<?php echo Yii::getPathOfAlias('application.runtime')  . DIRECTORY_SEPARATOR . ($anamnese->disease_heartattack == $key ? 'check_box_active.png' : 'check_box.png');?>">
						<?php echo $value ?>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
					<?php endforeach; ?>
				</li>
				<li>
					<?php foreach ($anamnese->getYesNoList() as $key => $value): ?>
						<img src="<?php echo Yii::getPathOfAlias('application.runtime')  . DIRECTORY_SEPARATOR . ($anamnese->disease_arterial_disorder == $key ? 'check_box_active.png' : 'check_box.png');?>">
						<?php echo $value ?>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
					<?php endforeach; ?>
				</li>
				<li>
					<?php foreach ($anamnese->getYesNoList() as $key => $value): ?>
						<img src="<?php echo Yii::getPathOfAlias('application.runtime')  . DIRECTORY_SEPARATOR . ($anamnese->disease_raynauld_syndrome == $key ? 'check_box_active.png' : 'check_box.png');?>">
						<?php echo $value ?>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
					<?php endforeach; ?>
				</li>
				<li>
					<?php foreach ($anamnese->getYesNoList() as $key => $value): ?>
						<img src="<?php echo Yii::getPathOfAlias('application.runtime')  . DIRECTORY_SEPARATOR . ($anamnese->disease_vasculitis == $key ? 'check_box_active.png' : 'check_box.png');?>">
						<?php echo $value ?>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
					<?php endforeach; ?>
				</li>
				<li>
					<?php foreach ($anamnese->getYesNoList() as $key => $value): ?>
						<img src="<?php echo Yii::getPathOfAlias('application.runtime')  . DIRECTORY_SEPARATOR . ($anamnese->disease_cold_sensitivity == $key ? 'check_box_active.png' : 'check_box.png');?>">
						<?php echo $value ?>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
					<?php endforeach; ?>
				</li>
				<li>
					<?php foreach ($anamnese->getYesNoList() as $key => $value): ?>
						<img src="<?php echo Yii::getPathOfAlias('application.runtime')  . DIRECTORY_SEPARATOR . ($anamnese->disease_sensory_disturbances == $key ? 'check_box_active.png' : 'check_box.png');?>">
						<?php echo $value ?>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
					<?php endforeach; ?>
				</li>
				<li>
					<?php foreach ($anamnese->getYesNoList() as $key => $value): ?>
						<img src="<?php echo Yii::getPathOfAlias('application.runtime')  . DIRECTORY_SEPARATOR . ($anamnese->disease_circulatory_disorder == $key ? 'check_box_active.png' : 'check_box.png');?>">
						<?php echo $value ?>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
					<?php endforeach; ?>
				</li>
				<li>
					<?php foreach ($anamnese->getYesNoList() as $key => $value): ?>
						<img src="<?php echo Yii::getPathOfAlias('application.runtime')  . DIRECTORY_SEPARATOR . ($anamnese->disease_nerve_damage == $key ? 'check_box_active.png' : 'check_box.png');?>">
						<?php echo $value ?>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
					<?php endforeach; ?>
				</li>
				<li>
					<?php foreach ($anamnese->getYesNoList() as $key => $value): ?>
						<img src="<?php echo Yii::getPathOfAlias('application.runtime')  . DIRECTORY_SEPARATOR . ($anamnese->disease_replantation == $key ? 'check_box_active.png' : 'check_box.png');?>">
						<?php echo $value ?>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
					<?php endforeach; ?>
				</li>
				<li>
					<?php foreach ($anamnese->getYesNoList() as $key => $value): ?>
						<img src="<?php echo Yii::getPathOfAlias('application.runtime')  . DIRECTORY_SEPARATOR . ($anamnese->disease_peripheral_lymphatics == $key ? 'check_box_active.png' : 'check_box.png');?>">
						<?php echo $value ?>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
					<?php endforeach; ?>
				</li>
				<li>
					<?php foreach ($anamnese->getYesNoList() as $key => $value): ?>
						<img src="<?php echo Yii::getPathOfAlias('application.runtime')  . DIRECTORY_SEPARATOR . ($anamnese->disease_hemoglobinemia == $key ? 'check_box_active.png' : 'check_box.png');?>">
						<?php echo $value ?>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
					<?php endforeach; ?>
				</li>
				<li>
					<?php foreach ($anamnese->getYesNoList() as $key => $value): ?>
						<img src="<?php echo Yii::getPathOfAlias('application.runtime')  . DIRECTORY_SEPARATOR . ($anamnese->disease_kidney_bladder == $key ? 'check_box_active.png' : 'check_box.png');?>">
						<?php echo $value ?>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
					<?php endforeach; ?>
				</li>
				<li>
					<?php foreach ($anamnese->getYesNoList() as $key => $value): ?>
						<img src="<?php echo Yii::getPathOfAlias('application.runtime')  . DIRECTORY_SEPARATOR . ($anamnese->disease_heart_circulatory == $key ? 'check_box_active.png' : 'check_box.png');?>">
						<?php echo $value ?>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
					<?php endforeach; ?>
				</li>
			</ul>
		</td>
    </tr>
    <tr>
        <td>
			Leiden Sie an weiteren Problemen an Ihrem Bewegungsapparat?<br/>
			<br/>
			Falls ja, an welchen?
		</td>
        <td>
			<?php foreach ($anamnese->getYesNoList() as $key => $value): ?>
				<img src="<?php echo Yii::getPathOfAlias('application.runtime')  . DIRECTORY_SEPARATOR . ($anamnese->musculoskeletal_problems == $key ? 'check_box_active.png' : 'check_box.png');?>">
				<?php echo $value ?>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
			<?php endforeach; ?>
			<br/>
			<div style="width:100%; border-bottom: 1px solid #000;"><?php echo $anamnese->musculoskeletal_problems_description ?></div>
		</td>
    </tr>
	<tr>
        <th colspan="2">Trainingsziele</th>
    </tr>
    <tr>
        <td colspan="2">
			<?php echo $anamnese->gaols ?>
		</td>
    </tr>
    <tr>
        <th colspan="2">Bemerkungen</th>
    </tr>
    <tr>
        <td colspan="2">
			<?php echo $anamnese->comments ?>
		</td>
    </tr>
</table>
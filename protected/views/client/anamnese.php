<?php $form=$this->beginWidget('CActiveForm', array(
	'id'=>'anamnese-form',
	'enableAjaxValidation'=>false,
)); ?>
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
        <td><?php echo $form->textField($anamnese,'address') ?></td>
    </tr>
    <tr>
        <td>Was für einen Beruf führen Sie aktuell aus?</td>
        <td><?php echo $form->textField($anamnese,'profession') ?></td>
    </tr>
    <tr>
        <td>Welche Tätigkeiten beinhaltet ihre Arbeit hauptsächlich?</td>
        <td><?php echo $form->radioButtonList($anamnese,'activities', $anamnese->getActivitiesList()) ?></td>
    </tr>
    <tr>
        <th colspan="2">Fragen zu körperlicher Aktivität in der Freizeit</th>
    </tr>
    <tr>
        <td>Wie sieht Ihre körperliche Beanspruchung in der Freizeit oder auf dem Arbeitsweg aus?</td>
        <td><?php echo $form->radioButtonList($anamnese,'physical_demands', $anamnese->getPhysicalDemandsList()) ?></td>
    </tr>
    <tr>
        <th colspan="2">Fragen zur sportlichen Aktivität und Regenerationsmassnahmen</th>
    </tr>
    <tr>
        <td>Welche Sportarten betreiben Sie regelmässig?</td>
        <td><?php echo $form->textArea($anamnese,'sportarts') ?></td>
    </tr>
    <tr>
        <td>In welchem Umfang betreiben Sie die erwähnten Sportarten? (Anzahl Stunden pro Woche)</td>
        <td><?php echo $form->textField($anamnese,'sportarts_scope') ?></td>
    </tr>
    <tr>
        <td>In welcher Intensität betreiben sie die erwähnten Sportarten?</td>
        <td><?php echo $form->radioButtonList($anamnese,'sportarts_intencity', $anamnese->getSportartsIntencityList()) ?></td>
    </tr>
    <tr>
        <td>Wieviele Stunden schlafen sie normalerweise  pro Nacht?</td>
        <td>
			Unter der Woche:<br/>
			<?php echo $form->textField($anamnese,'sleep_week') ?><br/>
			Am Wochenende:<br/>
			<?php echo $form->textField($anamnese,'sleep_weekend') ?><br/>
		</td>
    </tr>
    <tr>
        <td>Wieviele Stunden Entspannung gönnen Sie sich pro Tag?</td>
        <td>
			Unter der Woche:<br/>
			<?php echo $form->textField($anamnese,'relaxation_week') ?><br/>
			Am Wochenende:<br/>
			<?php echo $form->textField($anamnese,'relaxation_weekend') ?><br/>
		</td>
    </tr>
    <tr>
        <td>Wieviele trainingsfreie Tage pro Woche haben Sie?</td>
        <td><?php echo $form->textField($anamnese,'training_dayoff') ?></td>
    </tr>
    <tr>
        <th colspan="2">Fragen zum Aktuellen Gesundheitsstand</th>
    </tr>
	<tr>
		<td>Sind sie zur Zeit in ärztlicher Behandlung?</td>
		<td>
			<?php echo $form->radioButtonList($anamnese,'medical_treatment', $anamnese->getYesNoList(), array('separator' => '<span class="separator"></span>')) ?>
		</td>
	</tr>
	<tr>
		<td>Nehmen Sie regelmässig Medikmente?</td>
		<td>
			<?php echo $form->radioButtonList($anamnese,'taking_drugs', $anamnese->getYesNoList(), array('separator' => '<span class="separator"></span>')) ?>
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
			<?php echo $form->radioButtonList($anamnese,'injury', $anamnese->getYesNoList()) ?><br/>
			<br/>
			<ul class="inputs">
				<li><?php echo $form->textField($anamnese,'injury_type') ?></li>
				<li><?php echo $form->textField($anamnese,'injury_bodypart') ?></li>
				<li><?php echo $form->radioButtonList($anamnese,'injury_chronic', $anamnese->getYesNoList(), array('separator' => '<span class="separator"></span>')) ?></li>
			</ul>
		</td>
    </tr>
    <tr>
        <td style="vertical-align: top;">
			Leiden Sie an einer der folgenden Krankheiten?<br/><br/>
			<ul class="labels">
				<li>Herzinfarkt (<0.5 Jahre)</li>
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
				<li><?php echo $form->radioButtonList($anamnese,'disease_heartattack', $anamnese->getYesNoList(), array('separator' => '<span class="separator"></span>')) ?></li>
				<li><?php echo $form->radioButtonList($anamnese,'disease_arterial_disorder', $anamnese->getYesNoList(), array('separator' => '<span class="separator"></span>')) ?></li>
				<li><?php echo $form->radioButtonList($anamnese,'disease_raynauld_syndrome', $anamnese->getYesNoList(), array('separator' => '<span class="separator"></span>')) ?></li>
				<li><?php echo $form->radioButtonList($anamnese,'disease_vasculitis', $anamnese->getYesNoList(), array('separator' => '<span class="separator"></span>')) ?></li>
				<li><?php echo $form->radioButtonList($anamnese,'disease_cold_sensitivity', $anamnese->getYesNoList(), array('separator' => '<span class="separator"></span>')) ?></li>
				<li><?php echo $form->radioButtonList($anamnese,'disease_sensory_disturbances', $anamnese->getYesNoList(), array('separator' => '<span class="separator"></span>')) ?></li>
				<li><?php echo $form->radioButtonList($anamnese,'disease_circulatory_disorder', $anamnese->getYesNoList(), array('separator' => '<span class="separator"></span>')) ?></li>
				<li><?php echo $form->radioButtonList($anamnese,'disease_nerve_damage', $anamnese->getYesNoList(), array('separator' => '<span class="separator"></span>')) ?></li>
				<li><?php echo $form->radioButtonList($anamnese,'disease_replantation', $anamnese->getYesNoList(), array('separator' => '<span class="separator"></span>')) ?></li>
				<li><?php echo $form->radioButtonList($anamnese,'disease_peripheral_lymphatics', $anamnese->getYesNoList(), array('separator' => '<span class="separator"></span>')) ?></li>
				<li><?php echo $form->radioButtonList($anamnese,'disease_hemoglobinemia', $anamnese->getYesNoList(), array('separator' => '<span class="separator"></span>')) ?></li>
				<li><?php echo $form->radioButtonList($anamnese,'disease_kidney_bladder', $anamnese->getYesNoList(), array('separator' => '<span class="separator"></span>')) ?></li>
				<li><?php echo $form->radioButtonList($anamnese,'disease_heart_circulatory', $anamnese->getYesNoList(), array('separator' => '<span class="separator"></span>')) ?></li>
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
			<?php echo $form->radioButtonList($anamnese,'musculoskeletal_problems', $anamnese->getYesNoList(), array('separator' => '<span class="separator"></span>')) ?><br/>
			<br/>
			<?php echo $form->textField($anamnese,'musculoskeletal_problems_description') ?>
		</td>
    </tr>
    <tr>
        <th colspan="2">Trainingsziele</th>
    </tr>
    <tr>
        <td colspan="2">
			<?php echo $form->textArea($anamnese,'goals') ?>
		</td>
    </tr>
	<tr>
        <th colspan="2">Bemerkungen</th>
    </tr>
    <tr>
        <td colspan="2">
			<?php echo $form->textArea($anamnese,'comments') ?>
		</td>
    </tr>
</table>
<?php echo CHtml::submitButton('Save'); ?>
<?php $this->endWidget(); ?>